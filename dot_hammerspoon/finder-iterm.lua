-- finder-iterm.lua — Finder 의 **현재 폴더**에서 iTerm2 새 탭 열기 (⌃⌘⇧↓)
--
-- ── 왜 macOS 서비스로는 안 되는가 ────────────────────────────────────────────
-- iTerm2 의 "New iTerm2 Tab Here" 와 애플의 "New Terminal at Folder" 는 둘 다
-- Info.plist 에 이렇게 선언돼 있다:
--     NSSendTypes      = NSFilenamesPboardType, public.plain-text
--     NSRequiredContext = { NSTextContent: FilePath }
-- 즉 **항목이 선택돼 있어야만** 동작한다. 폴더를 열어놓고 아무것도 선택하지 않은
-- 상태에서는 서비스가 비활성이라 단축키를 눌러도 아무 일이 없다.
-- 실측: 폴더 선택 후 ⌃⌘⇧↓ → iTerm2 세션 6→7, 선택한 폴더에서 열림.
--       선택 없이 누르면 → 무반응 (사용자가 겪은 증상).
-- 그리고 서비스는 '선택한 폴더'에서 열기 때문에 애초에 '현재 폴더'를 못 여는 구조다.
--
-- 여기서는 Finder 창의 target 을 직접 읽으므로 선택이 필요 없다:
--   · 폴더 하나가 선택돼 있으면 → 그 폴더 (기존 서비스와 같은 동작 유지)
--   · 아니면                    → 창이 보고 있는 현재 폴더
--   · Finder 창이 없으면        → 데스크탑
--
-- 여는 건 `open -a iTerm <dir>` 한 줄로 충분하다. 기존 창에 **새 탭**으로 열리고,
-- 한글·공백이 섞인 경로도 그대로 처리된다 (실측: OneDrive 아래 "한글 폴더/공백 있는 이름").
--
-- 이벤트 탭이 아니라 hs.hotkey 라서 시스템 입력을 막을 위험이 없다.
-- Finder 최전면일 때만 키를 잡으므로 다른 앱에서는 ⌃⌘⇧↓ 가 원래대로 동작한다.

local M = {}

-- ---------------- 설정 ----------------
local BUNDLE   = "com.apple.finder"
local MODS     = { "ctrl", "cmd", "shift" }
local KEY      = "down"          -- 기존 서비스 단축키와 같은 키(근육 기억 유지)
local TERM_APP = "iTerm"         -- `open -a` 에 넘길 앱 이름
local DEBUG    = true

local LOGFILE = os.getenv("HOME") .. "/.hammerspoon/finder-iterm.log"
local function dbg(fmt, ...)
  if not DEBUG then return end
  local ok, s = pcall(string.format, fmt, ...)
  local f = io.open(LOGFILE, "a")
  if f then f:write(os.date("%H:%M:%S ") .. (ok and s or tostring(s)) .. "\n") f:close() end
end

-- 선택된 폴더 > 창의 현재 폴더 > 데스크탑 순으로 경로를 고른다.
-- 파일이 선택된 경우는 일부러 창의 현재 폴더로 떨어진다(그 파일의 부모와 같다).
local PATH_SCRIPT = [[
tell application "Finder"
  set sel to selection
  if (count of sel) is 1 then
    set one to item 1 of sel
    if (class of one is folder) or (class of one is disk) then
      return POSIX path of (one as alias)
    end if
  end if
  if (count of Finder windows) > 0 then
    return POSIX path of (target of front Finder window as alias)
  end if
  return POSIX path of (path to desktop folder)
end tell
]]

function M.open()
  local t0 = hs.timer.absoluteTime()
  local ok, path = hs.osascript.applescript(PATH_SCRIPT)
  local ms = (hs.timer.absoluteTime() - t0) / 1e6
  if not ok or type(path) ~= "string" or path == "" then
    dbg("경로를 못 얻었다 (%.0fms) ok=%s val=%s", ms, tostring(ok), tostring(path))
    return false
  end
  local attr = hs.fs.attributes(path)
  if not attr or attr.mode ~= "directory" then
    dbg("폴더가 아니다: %s", path)
    return false
  end
  -- hs.task 는 비동기라 핫키 콜백을 붙잡지 않는다.
  hs.task.new("/usr/bin/open", nil, { "-a", TERM_APP, path }):start()
  dbg("열기 (%.0fms): %s", ms, path)
  return true
end

function M.start()
  M.hotkey = hs.hotkey.new(MODS, KEY, function() M.open() end)

  -- Finder 최전면일 때만 가로챈다. 다른 앱에서는 시스템 동작 그대로.
  M.watcher = hs.application.watcher.new(function(_, ev, app)
    if not app or app:bundleID() ~= BUNDLE then return end
    if ev == hs.application.watcher.activated then
      M.hotkey:enable()
    elseif ev == hs.application.watcher.deactivated
        or ev == hs.application.watcher.terminated then
      M.hotkey:disable()
    end
  end)
  M.watcher:start()

  local front = hs.application.frontmostApplication()
  if front and front:bundleID() == BUNDLE then M.hotkey:enable() end

  dbg("=== finder-iterm 준비 (Finder 에서 ⌃⌘⇧↓ = 현재 폴더에서 iTerm2) ===")
  return M
end

function M.stop()
  if M.hotkey then M.hotkey:delete() M.hotkey = nil end
  if M.watcher then M.watcher:stop() M.watcher = nil end
end

return M
