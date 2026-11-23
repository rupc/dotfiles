-- ppt-ribbon.lua — PowerPoint 리본 명령을 윈도우 Alt 코드처럼 "키 순서"로 실행한다
--
-- 윈도우 PPT 는 Alt 를 누르면 리본에 글자 배지(KeyTips)가 뜨고, 그 글자를 순서대로
-- 누르면 명령이 실행된다:
--     Alt+H, S, H   = 도형 갤러리
--     Alt+H, F, C   = 글꼴 색
-- 맥 PPT 엔 KeyTips 자체가 없다. 그래서 같은 키 순서를 직접 만든다. 시작 키는 Cmd+H.
--     Cmd+H, S, H   = 도형 갤러리
--     Cmd+H, F, C   = 글꼴 색
-- 코드 길이에 제한은 없다 (트라이로 처리한다).
--
-- 구현: 리본의 AXMenuButton 을 찾아 **AXShowMenu** 액션을 준다.
--       (메뉴 바 삽입>도형 서브메뉴는 도형이 5개뿐이라 대체가 안 된다 — 실측 확인)
--
--       AXPress 를 쓰면 안 된다. 리본 메뉴 버튼은 분할 버튼이라 AXPress 는 "버튼의 기본 동작"
--       이고, 글꼴 색의 기본 동작은 팝업 열기가 아니라 **최근 색을 그대로 적용**하는 것이다.
--       (AXValue 가 현재 색 이름을 들고 있다: "진한 회색, 텍스트 1, 25% 더 밝게")
--       실측: AXPress 1ms 로 끝나고 색만 입혀짐 / AXShowMenu 29ms 로 팝업이 열림.
--
--       팝업은 앱·창의 AX 자식 목록에 전혀 나타나지 않는다(press 전후 목록 동일 — 실측).
--       유일하게 관측되는 신호는 **시스템 전역 포커스**다. 글꼴 색에 AXShowMenu 를 주면
--       포커스가 슬라이드(AXScrollArea)에서 버튼 바로 아래의 AXGroup 469,160 198x292
--       (= 색 팔레트)으로 옮겨가고, Escape 를 주면 다시 버튼으로 돌아온다.
--       그래서 새 명령을 추가한 뒤 확인할 때는 M.focused() 로 포커스를 찍어보면 된다.
--
-- ── PPT 에서 Cmd+H 는 앱 숨기기를 하지 않는다 ────────────────────────────────
-- 맥 기본 Cmd+H 는 앱 숨기기다. 이전 버전은 코드가 안 이어지면 숨기기로 넘겼는데,
-- 그 바람에 PPT 가 의도치 않게 사라지는 일이 실제로 두 번 생겼다(로그 15:47, 16:14).
-- 그래서 PPT 안에서는 Cmd+H 를 완전히 삼킨다. 숨기려면 메뉴의
-- 'PowerPoint > PowerPoint 숨기기' 나 Dock 을 쓰면 된다.
-- 다른 앱에서는 원래대로 동작한다 — PPT 최전면일 때만 후킹하기 때문이다.
--
-- 이벤트 탭이 아니라 hs.hotkey 라서 시스템 전체 입력을 막지 않는다. 그래도 AX 조회는
-- 리본 서브트리로 한정하고 시간 예산을 둔다 (전체 트리 순회는 12초까지 걸린다 — 실측).
-- 비상 정지: `killall Hammerspoon`.

local M = {}

-- ---------------- 설정 ----------------
local BUNDLE       = "com.microsoft.Powerpoint"
local CHORD_WINDOW = 1.2   -- 다음 글자를 기다리는 시간(초). 단계마다 새로 갱신된다
local BUDGET_MS    = 700   -- 리본에서 버튼을 찾는 데 쓸 예산(ms)
local TAB_SETTLE   = 0.25  -- 탭을 전환한 뒤 리본이 자리를 잡을 때까지 기다리는 시간(초)
local DEBUG        = true

-- ---------------- 리본 명령 정의 ----------------
-- code   : Cmd+H 뒤에 누를 글자 순서 (윈도우 KeyTips 와 같게 맞춘다)
-- titles : 리본 버튼 제목 (한국어 UI / 영문 UI)
-- tab    : 그 버튼이 있는 탭. 현재 탭에 없을 때만 이 탭으로 전환한다
-- action : (선택) 기본값 "AXShowMenu". 팝업이 아니라 즉시 실행돼야 하는 명령만 "AXPress"
local COMMANDS = {
  -- 도형은 맥에선 삽입 탭에만 있다. 홈 탭의 "그리기" 버튼은 AXShowMenu 로 아무것도
  -- 열리지 않는 걸 확인했으므로(포커스 안 움직임) 삽입 탭으로 전환해서 누른다.
  { code = { "s", "h" }, titles = { "도형", "Shapes" },       tab = { "삽입", "Insert" }, label = "도형 갤러리" },
  { code = { "f", "c" }, titles = { "글꼴 색", "Font Color" }, tab = { "홈", "Home" },     label = "글꼴 색" },
}

local LOGFILE = os.getenv("HOME") .. "/.hammerspoon/ppt-ribbon.log"
local function dbg(fmt, ...)
  if not DEBUG then return end
  local ok, s = pcall(string.format, fmt, ...)
  local f = io.open(LOGFILE, "a")
  if f then f:write(os.date("%H:%M:%S ") .. (ok and s or tostring(s)) .. "\n") f:close() end
end

local ax = hs.axuielement
local function ms(t0) return (hs.timer.absoluteTime() - t0) / 1e6 end

local function asSet(list)
  local t = {}
  for _, v in ipairs(list) do t[v] = true end
  return t
end

-- 리본(AXTabGroup) 안에서만 메뉴 버튼을 찾는다. 창 전체를 뒤지지 않는다.
-- 반환: 버튼(없으면 nil), 리본 탭 그룹(탭 전환에 필요)
local function findInRibbon(winEl, titles, deadline)
  local want = asSet(titles)
  local found = nil
  local function walk(el, d)
    if found or d > 6 or hs.timer.absoluteTime() > deadline then return end
    if el:attributeValue("AXRole") == "AXMenuButton" then
      local t = el:attributeValue("AXTitle")
      if t and want[t] then found = el return end
    end
    for _, k in ipairs(el:attributeValue("AXChildren") or {}) do walk(k, d + 1) end
  end
  for _, k in ipairs(winEl:attributeValue("AXChildren") or {}) do
    if k:attributeValue("AXRole") == "AXTabGroup" then
      walk(k, 0)
      return found, k
    end
  end
  return nil, nil
end

-- 버튼이 현재 탭에 없을 때 해당 탭으로 전환
local function selectTab(tabGroup, tabTitles)
  local want = asSet(tabTitles)
  for _, k in ipairs(tabGroup:attributeValue("AXChildren") or {}) do
    if k:attributeValue("AXRole") == "AXRadioButton" then
      local t = k:attributeValue("AXTitle")
      if t and want[t] then
        pcall(function() k:performAction("AXPress") end)
        return true
      end
    end
  end
  return false
end

-- 최후 폴백: 메뉴 바 삽입 > 도형 (도형 5개뿐이지만 아무것도 안 되는 것보다 낫다)
local function menuBarShapes()
  local ok = pcall(function()
    return hs.osascript.applescript([[
      tell application "System Events" to tell process "Microsoft PowerPoint"
        click menu item "도형" of menu 1 of menu bar item "삽입" of menu bar 1
      end tell]])
  end)
  dbg("메뉴 바 폴백: %s", tostring(ok))
  return ok
end

-- 리본 버튼 하나를 누른다
function M.press(cmd)
  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= BUNDLE then return false end

  local t0 = hs.timer.absoluteTime()
  local okAll, result = pcall(function()
    local appEl = ax.applicationElement(app)
    if not appEl then return false end
    appEl:setTimeout(0.5)
    local win = appEl:attributeValue("AXFocusedWindow")
      or (appEl:attributeValue("AXWindows") or {})[1]
    if not win then return false end
    win:setTimeout(0.5)

    local btn, tabGroup = findInRibbon(win, cmd.titles, t0 + BUDGET_MS * 1e6)
    if not btn and tabGroup and cmd.tab then
      -- 현재 탭에 없으면 지정된 탭으로 옮기고 한 번 더
      if selectTab(tabGroup, cmd.tab) then
        hs.timer.usleep(math.floor(TAB_SETTLE * 1e6))   -- 리본이 다시 그려질 시간
        btn = findInRibbon(win, cmd.titles, hs.timer.absoluteTime() + BUDGET_MS * 1e6)
      end
    end
    if not btn then return false end
    -- 팝업을 여는 건 AXShowMenu 다. 그 액션이 없는 버튼만 AXPress 로 떨어진다.
    local action = cmd.action or "AXShowMenu"
    local ok = false
    for _, a in ipairs(btn:actionNames() or {}) do
      if a == action then ok = true break end
    end
    if not ok then action = "AXPress" end
    btn:performAction(action)
    return action
  end)

  if okAll and result then
    dbg("%s 열림 (%s, %.0fms)", cmd.label, tostring(result), ms(t0))
    return true
  end
  dbg("%s 버튼 못 찾음 (%.0fms)", cmd.label, ms(t0))
  if cmd.titles[1] == "도형" then return menuBarShapes() end
  return false
end

-- 이름으로 실행 (수동 테스트용): M.run("f c")
function M.run(codeStr)
  for _, c in ipairs(COMMANDS) do
    if table.concat(c.code, " ") == codeStr then return M.press(c) end
  end
  dbg("그런 코드 없음: %s", tostring(codeStr))
  return false
end

-- ---------------- Cmd+H 코드 입력 ----------------
-- COMMANDS 로 트라이(글자별 갈림길 트리)를 만든다. 단계 수 제한이 없어서
-- S,H 든 F,C 든 더 긴 코드든 표에 한 줄 넣는 것만으로 동작한다.
local root, allKeys, conflicts = { kids = {} }, {}, {}
for _, c in ipairs(COMMANDS) do
  local node = root
  for i, k in ipairs(c.code) do
    node.kids[k] = node.kids[k] or { kids = {} }
    node = node.kids[k]
    allKeys[k] = true
    -- 짧은 코드가 긴 코드의 접두면 짧은 쪽이 항상 먼저 실행돼 긴 쪽이 죽는다
    if node.cmd and i < #c.code then conflicts[#conflicts+1] = table.concat(c.code, " ") end
  end
  if next(node.kids) then conflicts[#conflicts+1] = table.concat(c.code, " ") end
  node.cmd = c
end

local chord, chordTimer, hotkey, cur, typed

local function exitChord()
  if chordTimer then chordTimer:stop() chordTimer = nil end
  cur, typed = nil, nil
  if chord then chord:exit() end
end

-- 다음 글자를 기다리는 타이머를 건다. 시간이 지나면 그냥 조용히 취소한다.
-- (예전엔 여기서 앱 숨기기로 넘겼다 — 사고의 원인이라 없앴다)
local function armTimer()
  if chordTimer then chordTimer:stop() end
  chordTimer = hs.timer.doAfter(CHORD_WINDOW, function()
    local t = typed
    exitChord()
    dbg("코드 미완성%s — 취소 (숨기기 안 함)", t and (" ("..t..")") or "")
  end)
end

local function onKey(key)
  typed = typed and (typed .. " " .. key) or key
  local node = (cur or root).kids[key]
  if not node then
    local t = typed
    exitChord()
    dbg("모르는 코드: %s", t)
    return
  end
  if node.cmd then                 -- 코드 완성 → 실행 (M.press 가 자기 로그를 남긴다)
    exitChord()
    M.press(node.cmd)
    return
  end
  cur = node                       -- 아직 접두 → 다음 글자를 기다린다
  armTimer()
  dbg("접두 %s — 다음 글자 대기", typed)
end

-- 팝업이 실제로 열렸는지 확인하는 유일한 방법: 시스템 전역 포커스를 찍어본다.
-- 팝업이 열려 있으면 리본 버튼 바로 아래의 AXGroup 이 잡힌다.
--   hs -c 'print(pptRibbon.focused())'
function M.focused()
  local fe = ax.systemWideElement():attributeValue("AXFocusedUIElement")
  if not fe then return "focused=nil" end
  local p, sz = fe:attributeValue("AXPosition"), fe:attributeValue("AXSize")
  return string.format("%s t=%s %s %s",
    tostring(fe:attributeValue("AXRole")), tostring(fe:attributeValue("AXTitle")),
    p and string.format("%.0f,%.0f", p.x, p.y) or "-",
    sz and string.format("%.0fx%.0f", sz.w, sz.h) or "-")
end

-- 테스트용: 실제 키 입력 없이 코드 글자 하나를 입력기에 먹인다 (라우팅만 확인).
-- 슬라이드에 글자가 잘못 들어갈 위험 없이 Cmd+H 뒤 동작을 검증할 수 있다.
function M._feed(key) onKey(key) end

function M.start()
  chord = hs.hotkey.modal.new()
  for key in pairs(allKeys) do
    chord:bind({}, key, function() onKey(key) end)
  end
  chord:bind({}, "escape", function() exitChord() end)

  -- PPT 안에서는 Cmd+H 가 앱 숨기기를 하지 않는다. 코드가 안 와도 그냥 취소된다.
  hotkey = hs.hotkey.new({ "cmd" }, "h", function()
    local app = hs.application.frontmostApplication()
    if not app or app:bundleID() ~= BUNDLE then return end
    cur, typed = nil, nil          -- 이전에 남은 코드 상태를 버리고 처음부터
    chord:enter()
    armTimer()
  end)

  -- PPT 최전면일 때만 Cmd+H 를 가로챈다. 다른 앱에서는 시스템 동작 그대로.
  M.watcher = hs.application.watcher.new(function(_, ev, app)
    if not app or app:bundleID() ~= BUNDLE then return end
    if ev == hs.application.watcher.activated then
      hotkey:enable()
    elseif ev == hs.application.watcher.deactivated
        or ev == hs.application.watcher.terminated then
      exitChord()
      hotkey:disable()
    end
  end)
  M.watcher:start()

  local front = hs.application.frontmostApplication()
  if front and front:bundleID() == BUNDLE then hotkey:enable() end

  local codes = {}
  for _, c in ipairs(COMMANDS) do
    codes[#codes+1] = string.upper(table.concat(c.code, "-")) .. "=" .. c.label
  end
  if #conflicts > 0 then
    dbg("경고: 다른 코드의 접두가 되는 코드가 있다 → %s", table.concat(conflicts, ", "))
  end
  dbg("=== ppt-ribbon 준비 (Cmd+H → %s / 숨기기 없음) ===", table.concat(codes, ", "))
  return M
end

function M.stop()
  exitChord()
  if hotkey then hotkey:delete() hotkey = nil end
  if M.watcher then M.watcher:stop() M.watcher = nil end
end

return M
