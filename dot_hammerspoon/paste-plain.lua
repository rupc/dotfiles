-- paste-plain.lua — Word/PowerPoint 에서 Ctrl+Shift+V = 평문으로 붙여넣기
--
-- ── 왜 Karabiner 로는 부족했나 ──────────────────────────────────────────────
-- 처음엔 Karabiner 로 Ctrl+Shift+V → ⌥⇧⌘V(서식 붙여넣기 및 일치) 로 바꿨다.
-- 문서 본문에서는 잘 되지만 **오른쪽 애드인 창(ChatGPT/Claude)에서는 안 먹는다.**
-- 그 창은 PPT 창 안의 웹뷰(AX 상 `AXGroup desc="ChatGPT Office 추가 기능"`)라
-- Office 의 '서식 붙여넣기 및 일치' 명령이 거기까지 닿지 않는다.
-- (프로세스는 PowerPoint 하나뿐이라 Karabiner 규칙 자체는 정상 발동했다 — 실측)
--
-- ── 그래서 클립보드를 직접 평평하게 만든다 ──────────────────────────────────
-- PPT 에서 복사하면 클립보드에 플레이버가 15개나 붙는다 (실측):
--   public.tiff, com.adobe.pdf, public.rtf, public.html, com.apple.webarchive,
--   public.utf8-plain-text, com.microsoft.DataObject ...
-- 붙여넣는 쪽이 이 중 뭘 고르냐에 따라 이미지로 붙기도 한다. 그래서 평문만 남기고
-- ⌘V 를 보낸다. 이러면 문서 본문이든 웹 애드인 창이든 **가리지 않고** 평문으로 붙는다.
--
-- 붙여넣은 뒤에는 원래 클립보드를 통째로 되돌린다. 되돌리기 직전에 changeCount 를
-- 확인해서, 그 사이 사용자가 뭔가 새로 복사했으면 건드리지 않는다.
--
-- 이벤트 탭이 아니라 hs.hotkey 라서 입력 마비 위험은 없다.
-- Word/PowerPoint 최전면일 때만 키를 잡으므로 Finder 의 Ctrl+Shift+V
-- (이동 붙여넣기, Karabiner 규칙)는 그대로 살아 있다.

local M = {}

-- ---------------- 설정 ----------------
local BUNDLES = {
  ["com.microsoft.Word"]       = true,
  ["com.microsoft.Powerpoint"] = true,
}
local MODS          = { "ctrl", "shift" }
local KEY           = "v"
local RESTORE_DELAY = 0.6    -- 붙여넣기가 끝날 시간을 준 뒤 원래 클립보드 복원(초)
local DEBUG         = true

local LOGFILE = os.getenv("HOME") .. "/.hammerspoon/paste-plain.log"
local function dbg(fmt, ...)
  if not DEBUG then return end
  local ok, s = pcall(string.format, fmt, ...)
  local f = io.open(LOGFILE, "a")
  if f then f:write(os.date("%H:%M:%S ") .. (ok and s or tostring(s)) .. "\n") f:close() end
end

-- 클립보드를 평문만 남기고 납작하게 만든다.
-- 반환: 원래 내용 전체(복원용), 우리가 쓴 뒤의 changeCount, 평문 길이
-- 평문이 없으면(이미지만 복사한 경우 등) nil 을 반환하고 클립보드를 건드리지 않는다.
function M.flatten()
  local text = hs.pasteboard.readString()
  if not text or text == "" then return nil end
  local backup = hs.pasteboard.readAllData()
  hs.pasteboard.setContents(text)
  return backup, hs.pasteboard.changeCount(), #text
end

-- 백업을 되돌린다. 그 사이 사용자가 새로 복사했으면(changeCount 가 달라졌으면) 넘어간다.
function M.restore(backup, ours)
  if not backup then return false end
  if hs.pasteboard.changeCount() ~= ours then
    dbg("복원 생략 — 그 사이 클립보드가 바뀌었다")
    return false
  end
  local ok = hs.pasteboard.writeAllData(backup)
  return ok and true or false
end

function M.paste()
  local backup, ours, n = M.flatten()
  if not backup then
    dbg("평문 없음 → 그냥 ⌘V")
    hs.eventtap.keyStroke({ "cmd" }, "v")
    return false
  end
  dbg("평문 %d자로 붙여넣기", n)
  hs.eventtap.keyStroke({ "cmd" }, "v")
  hs.timer.doAfter(RESTORE_DELAY, function()
    local restored = M.restore(backup, ours)
    dbg("클립보드 복원: %s", tostring(restored))
  end)
  return true
end

function M.start()
  M.hotkey = hs.hotkey.new(MODS, KEY, function() M.paste() end)

  -- Word/PowerPoint 최전면일 때만 가로챈다. 다른 앱에서는 원래대로.
  M.watcher = hs.application.watcher.new(function(_, ev, app)
    if not app then return end
    local id = app:bundleID()
    if not id or not BUNDLES[id] then return end
    if ev == hs.application.watcher.activated then
      M.hotkey:enable()
    elseif ev == hs.application.watcher.deactivated
        or ev == hs.application.watcher.terminated then
      M.hotkey:disable()
    end
  end)
  M.watcher:start()

  local front = hs.application.frontmostApplication()
  if front and front:bundleID() and BUNDLES[front:bundleID()] then M.hotkey:enable() end

  dbg("=== paste-plain 준비 (Word/PPT 에서 Ctrl+Shift+V = 평문 붙여넣기) ===")
  return M
end

function M.stop()
  if M.hotkey then M.hotkey:delete() M.hotkey = nil end
  if M.watcher then M.watcher:stop() M.watcher = nil end
end

return M
