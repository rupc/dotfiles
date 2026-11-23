-- ppt-thumb-zoom.lua — PowerPoint 축소판(슬라이드 미리보기) 창에서 Ctrl+휠 = 확대/축소
--
-- 윈도우 PPT 동작 재현: 왼쪽 축소판 창 위에 마우스를 두고 Ctrl+휠을 굴리면
-- 축소판 창이 넓어지고/좁아지면서 썸네일이 커지고/작아진다.
-- 축소판 창 밖(슬라이드 편집 영역 등)의 Ctrl+휠은 건드리지 않고 그대로 흘려보내므로
-- 기존 LinearMouse 의 pinchZoom(콘텐츠 줌)은 그대로 동작한다.
--
-- 원리: 축소판 창과 편집 영역 사이 AXSplitter 의 AXValue(=축소판 창 폭)가 쓰기 가능하다.
--       마우스 드래그를 합성할 필요 없이 값만 바꾸면 PPT 가 알아서 썸네일을 다시 그린다.
-- 왜 Hammerspoon 인가: Karabiner 는 휠을 트리거로 못 잡고, LinearMouse 는 "화면 어느
--       영역인지"를 구분하지 못한다. 커서 위치 판별이 필요해서 이벤트 탭이 불가피하다.
--
-- ── 안전 설계 (실측 기반) ──────────────────────────────────────────────────────
-- 이벤트 탭 콜백은 시스템 전체 입력 전달을 막고 실행된다. 즉 콜백이 느리면 그동안
-- 모든 앱의 스크롤이 얼어붙는다. 실측값: 트리 전체 순회 12,063ms(사고 원인) /
-- 고정 경로 하강 5.5ms / 좌표·값 읽기 0.48ms / 스플리터 쓰기 53.8ms.
-- 이 숫자에서 나온 규칙:
--   1. 탭은 PPT 가 최전면일 때만 존재한다 (벗어나면 즉시 파괴 → 사고 반경 = PPT 뿐)
--   2. 콜백 안에서 AX 호출 0회. 미리 캐시해둔 사각형과 좌표 산술 비교만 한다
--   3. 좌표 조회(AX)는 탭을 잠시 내린 상태에서만 한다 → 입력이 막힐 여지 자체를 없앤다
--   4. 조회 경로는 관측된 고정 경로만. 트리 전체 탐색 금지 + 전체 예산(BUDGET_MS) 초과 시 포기
--   5. AX 타임아웃은 우리가 들고 있는 모든 요소에 개별로 건다
--      (앱 요소에만 걸면 자식 요소 조회에 적용되지 않는다 — 2026-08-13 실측: 2349ms 지연)
--   6. 느리면 일단 쿴다운 후 재시도. PPT 시작 직후처럼 일시적으로 느린 경우가 있어서
--      한 번 느렸다고 세션 내내 죽이지 않는다. 연속 STRIKES 회 실패 시에만 완전 정지
--   7. 리사이즈(54ms)는 콜백 밖에서, 휠 델타를 모아 한 번만 적용
-- 비상 정지: `killall Hammerspoon` → 그 즉시 탭까지 전부 사라진다.

local M = {}

-- ---------------- 설정 ----------------
local BUNDLE     = "com.microsoft.Powerpoint"
local STEP       = 24     -- 휠 한 칸당 축소판 창 폭 변화(px)
local MIN_W      = 90     -- 최소 폭
local MAX_FRAC   = 0.45   -- 최대 폭 = 창 폭의 45%
local INVERT     = false  -- 휠 방향이 반대로 느껴지면 true
local DEBOUNCE   = 0.05   -- 휠 델타를 모으는 시간(초). 쓰기 54ms 라 매 이벤트 적용은 금물
local REFRESH    = 8      -- 캐시한 좌표 갱신 주기(초) — 창 이동/수동 드래그 대응
-- 좌표 조회(탭을 내린 상태에서 돈다 → 느려도 입력을 막지 않는다)의 상한.
-- 2026-08-20 실측: PPT 상태에 따라 같은 17개 요소 조회가 5.5ms ~ 533ms 로 요동친다.
-- 예전 값(0.1s / 150ms)은 너무 빡빡해서 기능이 계속 휴면으로 빠졌다.
local AX_TIMEOUT = 0.5    -- 조회용 AX 응답 대기 상한(초)
-- 2026-08-27 재실측: 같은 조회가 1867~2572ms 까지 늘어났다(PPT 문서 여러 개 열린 상태).
-- 900ms 예산이 연속으로 터져서 안전장치가 기능을 세션 내내 꺼버렸다.
-- 이 조회는 **탭을 내린 상태에서만** 돌기 때문에 예산이 커도 입력이 막히지 않는다.
-- (다만 그동안 Hammerspoon 스레드는 붙잡히므로 무한정 키우지는 않는다)
local BUDGET_MS  = 3000   -- 좌표 조회 전체 예산(ms). 넘으면 포기하고 나중에 재시도
-- 쓰기는 탭이 살아있는 채로 돌기 때문에 별도로 짧게 잡는다 (실측 54ms)
local WRITE_TIMEOUT = 0.15
local COOLDOWN   = 20     -- 느려서 포기했을 때 다시 시도할 때까지 대기(초)
local STRIKES    = 3      -- 이 횟수만큼 쌓이면 긴 휴식에 들어간다
-- 실패가 이 시간(초)보다 오래 전이면 '연속'으로 치지 않고 카운터를 리셋한다.
-- 이게 없어서 7분 간격으로 난 실패 3개가 누적돼 기능이 통째로 죽었다 (2026-08-27).
local STRIKE_WINDOW = 120
-- 실패가 쌓여도 영구 정지시키지 않는다. 길게 쉬었다가 스스로 다시 시도한다.
local LONG_COOLDOWN = 600
local DEBUG      = true   -- 로그: ~/.hammerspoon/ppt-thumb-zoom.log

-- ---------------- 로깅 ----------------
local LOGFILE = os.getenv("HOME") .. "/.hammerspoon/ppt-thumb-zoom.log"
local function dbg(fmt, ...)
  if not DEBUG then return end
  local ok, s = pcall(string.format, fmt, ...)
  local f = io.open(LOGFILE, "a")
  if f then
    f:write(os.date("%H:%M:%S ") .. (ok and s or ("[fmt err] " .. tostring(s))) .. "\n")
    f:close()
  end
end

-- ---------------- 상태 ----------------
local ax    = hs.axuielement
local props = hs.eventtap.event.properties

local st = { appEl = nil, win = nil, splitter = nil, area = nil,
             rect = nil,   -- 축소판 창 사각형 — 콜백은 이것만 본다
             val = nil,    -- 스플리터 현재 값 (우리가 쓴 값을 기억 → AX 재조회 불필요)
             maxW = nil }

local tap, refreshTimer, applyTimer
local pending, acc = 0, 0
local strikes, cooldownUntil, disabled, lastScroll = 0, 0, false, 0
local lastFail = 0   -- 마지막 실패 시각(초). STRIKE_WINDOW 밖이면 연속으로 안 센다

local function ms(t0) return (hs.timer.absoluteTime() - t0) / 1e6 end
local function nowS() return hs.timer.secondsSinceEpoch() end

-- 우리가 들고 있는 모든 요소에 개별로 타임아웃을 건다.
-- 앱 요소에만 걸면 자식 요소 조회에는 적용되지 않는다 (실측으로 확인된 함정).
local function bound(el)
  if el then pcall(function() el:setTimeout(AX_TIMEOUT) end) end
  return el
end

-- ---------------- 축소판 창 찾기 (고정 경로 + 예산) ----------------
-- 로케일 문자열(desc="축소판 그림 창")에 기대지 않고 구조로 판별한다.
-- 경로: 창 → AXSplitGroup → AXGroup → AXSplitGroup → [AXScrollArea(축소판) | AXSplitter]
-- 창 오른쪽 끝에도 AXSplitter 가 하나 더 있어서, "스플리터 왼쪽에 있고 AXList 를 품은
-- 스크롤 영역"이라는 조건으로 축소판 창 쪽 스플리터만 고른다.
local function kidsByRole(el, role)
  local res = {}
  for _, k in ipairs(el:attributeValue("AXChildren") or {}) do
    if k:attributeValue("AXRole") == role then res[#res + 1] = bound(k) end
  end
  return res
end

local function descend(win, deadline)
  local function over() return hs.timer.absoluteTime() > deadline end
  if over() then return nil, "budget" end
  local sg1 = kidsByRole(win, "AXSplitGroup")[1]
  if over() then return nil, "budget" end
  local grp = sg1 and kidsByRole(sg1, "AXGroup")[1]
  if over() then return nil, "budget" end
  local sg2 = grp and kidsByRole(grp, "AXSplitGroup")[1]
  if not sg2 then return nil, "nopane" end
  if over() then return nil, "budget" end

  local areas, splits = kidsByRole(sg2, "AXScrollArea"), kidsByRole(sg2, "AXSplitter")
  for _, sp in ipairs(splits) do
    if over() then return nil, "budget" end
    local sps, spp = sp:attributeValue("AXSize"), sp:attributeValue("AXPosition")
    if sps and spp and sps.h > sps.w then            -- 세로 스플리터만
      for _, a in ipairs(areas) do
        local ap, asz = a:attributeValue("AXPosition"), a:attributeValue("AXSize")
        if ap and asz and (ap.x + asz.w) <= (spp.x + sps.w + 2) then   -- 스플리터 왼쪽
          for _, c in ipairs(a:attributeValue("AXChildren") or {}) do
            if c:attributeValue("AXRole") == "AXList" then             -- 축소판 목록 보유
              return { splitter = sp, area = a }, nil
            end
          end
        end
      end
    end
  end
  return nil, "nopane"
end

-- 실제 AX 조회. 반드시 refresh() 를 통해서만 불린다 (탭이 내려간 상태 보장).
local function doRefresh(deadline)
  if not st.appEl then
    local app = hs.application.get(BUNDLE)
    if not app then return nil, "noapp" end
    st.appEl = bound(ax.applicationElement(app))
    if not st.appEl then return nil, "noapp" end
  end
  if not st.win or not st.win:isValid() then
    st.win = bound(st.appEl:attributeValue("AXFocusedWindow")
      or (st.appEl:attributeValue("AXWindows") or {})[1])
  end
  if not st.win then return nil, "nowin" end

  local found, why = descend(st.win, deadline)
  if not found then return nil, why end

  local ap  = found.area:attributeValue("AXPosition")
  local asz = found.area:attributeValue("AXSize")
  local wsz = st.win:attributeValue("AXSize")
  local v   = found.splitter:attributeValue("AXValue")
  if not (ap and asz and wsz and type(v) == "number") then return nil, "attrs" end

  st.splitter, st.area = found.splitter, found.area
  -- 쓰기는 탭이 살아있는 채로 도니 스플리터만 더 짧은 타임아웃으로 조인다
  pcall(function() st.splitter:setTimeout(WRITE_TIMEOUT) end)
  st.rect = { x = ap.x, y = ap.y, w = asz.w, h = asz.h }
  st.val, st.maxW = v, math.floor(wsz.w * MAX_FRAC)
  return true, nil
end

-- 좌표 갱신. AX 작업 동안에는 탭을 내려서 입력이 막힐 여지를 원천 제거한다.
local function refresh()
  if disabled then return false end
  if nowS() < cooldownUntil then return false end

  local wasRunning = tap ~= nil
  if wasRunning then tap:stop() end

  local t0 = hs.timer.absoluteTime()
  local ok, res, why = pcall(doRefresh, t0 + BUDGET_MS * 1e6)
  local took = ms(t0)
  if not ok then res, why = nil, "error:" .. tostring(res) end

  if wasRunning and not disabled then tap:start() end

  if res then
    strikes = 0
    -- 예산의 절반을 넘기기 시작하면 미리 남긴다. 이 값이 계속 오르면 BUDGET_MS 를 올릴 것.
    -- (예산이 조용히 터져서 기능이 죽는 걸 로그 없이 겪은 적이 있다)
    if took > BUDGET_MS * 0.5 then
      dbg("주의: 좌표 조회 %.0fms — 예산 %dms 의 절반 초과", took, BUDGET_MS)
    end
    return true
  end

  st.rect = nil   -- 판정 불가 → 콜백은 조용히 통과만 시킨다
  if why == "nopane" or why == "noapp" or why == "nowin" then
    return false  -- 정상적인 부재(슬라이드 정렬 보기 등)는 실패로 세지 않는다
  end

  local now = nowS()
  if lastFail > 0 and (now - lastFail) > STRIKE_WINDOW then strikes = 0 end
  strikes = strikes + 1
  lastFail = now
  if strikes >= STRIKES then
    strikes = 0                      -- 리셋하고 길게 쉰다 (영구 정지 아님)
    cooldownUntil = now + LONG_COOLDOWN
    dbg("좌표 조회 실패(%s, %.0fms) — %d회 누적, %d초 쉬었다가 자동 재시도",
        tostring(why), took, STRIKES, LONG_COOLDOWN)
    hs.notify.new({
      title = "PPT 축소판 줌 일시 중지",
      informativeText = "PowerPoint 응답이 느려 잠시 쉽니다. 10분 뒤 자동으로 다시 시도합니다.",
    }):send()
  else
    cooldownUntil = now + COOLDOWN
    dbg("좌표 조회 실패(%s, %.0fms) — %d/%d, %d초 후 재시도",
        tostring(why), took, strikes, STRIKES, COOLDOWN)
  end
  return false
end

-- ---------------- 리사이즈 적용 (콜백 밖) ----------------
-- 모아둔 휠 칸 수를 한 번의 AX 쓰기로 반영한다. 쓰기가 54ms 라 이게 핵심이다.
local function applyPending()
  applyTimer = nil
  local steps = pending
  pending = 0
  if steps == 0 or disabled or not st.splitter or not st.val then return end

  local nv = st.val + steps * STEP
  local maxW = st.maxW or 500
  if nv < MIN_W then nv = MIN_W elseif nv > maxW then nv = maxW end
  if nv == st.val then return end

  local prev = st.val
  local t0 = hs.timer.absoluteTime()
  local ok = pcall(function() st.splitter:setAttributeValue("AXValue", nv) end)
  local took = ms(t0)
  if not ok then
    dbg("스플리터 쓰기 실패 → 좌표 재조회")
    st.rect = nil
    return
  end

  -- AX 재조회 없이 캐시를 직접 갱신 (폭이 늘어난 만큼 사각형도 넓어진다)
  st.val = nv
  if st.rect then st.rect.w = st.rect.w + (nv - prev) end
  dbg("축소판 폭 %.0f → %.0f (steps=%d, 쓰기 %.0fms)", prev, nv, steps, took)
end

-- ---------------- 이벤트 탭 콜백 ----------------
-- 여기서는 AX 를 절대 호출하지 않는다. flags 확인 + 사각형 포함 판정 + 산술뿐.
local function onScroll(e)
  if disabled then return false end
  if not e:getFlags().ctrl then return false end

  local r = st.rect
  if not r then return false end

  local p = e:location()
  if not p then return false end
  if p.x < r.x or p.x > (r.x + r.w) or p.y < r.y or p.y > (r.y + r.h) then
    return false      -- 축소판 창 밖 → LinearMouse 의 pinchZoom 이 처리하게 통과
  end

  lastScroll = nowS()

  local d = e:getProperty(props.scrollWheelEventDeltaAxis1)
  if d == 0 then
    d = (e:getProperty(props.scrollWheelEventPointDeltaAxis1) or 0) / 10
  end
  if d == 0 then return true end

  if (acc > 0 and d < 0) or (acc < 0 and d > 0) then acc = 0 end   -- 방향 전환 시 리셋
  acc = acc + d
  local steps = 0
  while acc >= 1 do steps = steps + 1; acc = acc - 1 end
  while acc <= -1 do steps = steps - 1; acc = acc + 1 end
  if steps ~= 0 then
    if INVERT then steps = -steps end
    pending = pending + steps
    if not applyTimer then applyTimer = hs.timer.doAfter(DEBOUNCE, applyPending) end
  end
  return true   -- 소비: 아래(LinearMouse)로 안 내려감
end

-- ---------------- 탭 수명 관리 ----------------
local function stopTap()
  if refreshTimer then refreshTimer:stop() refreshTimer = nil end
  if applyTimer then applyTimer:stop() applyTimer = nil end
  if tap then tap:stop() tap = nil dbg("탭 정지") end
  pending, acc = 0, 0
  st.rect = nil
end

local function startTap()
  if disabled or tap then return end
  if not refresh() then return end          -- 좌표를 못 잡으면 탭 자체를 안 만든다
  tap = hs.eventtap.new({ hs.eventtap.event.types.scrollWheel }, function(e)
    local ok, consumed = pcall(onScroll, e)
    if not ok then dbg("콜백 에러: %s", tostring(consumed)) return false end
    return consumed == true
  end)
  tap:start()
  refreshTimer = hs.timer.doEvery(REFRESH, function()
    if not tap then return end
    if nowS() - lastScroll < 1 then return end   -- 휠 굴리는 중엔 건드리지 않는다
    refresh()
  end)
  dbg("탭 시작 — pane=%.0f,%.0f %.0fx%.0f splitter=%.0f",
      st.rect.x, st.rect.y, st.rect.w, st.rect.h, st.val or -1)
end

-- PPT 가 최전면인데 아직 좌표를 못 잡은 상태(시작 직후·쿨다운 중)를 위해
-- 가볍게 재시도한다. 탭이 이미 있으면 refreshTimer 가 담당하므로 아무것도 안 한다.
local function retryTick()
  if disabled or tap then return end
  local front = hs.application.frontmostApplication()
  if front and front:bundleID() == BUNDLE then startTap() end
end

function M.start()
  M.watcher = hs.application.watcher.new(function(_, ev, app)
    if not app or app:bundleID() ~= BUNDLE then return end
    if ev == hs.application.watcher.activated then
      st.appEl, st.win = nil, nil          -- 앱이 재시작됐을 수 있으니 새로 잡는다
      startTap()
    elseif ev == hs.application.watcher.deactivated
        or ev == hs.application.watcher.terminated then
      stopTap()
      st.appEl, st.win, st.splitter, st.area = nil, nil, nil, nil
    end
  end)
  M.watcher:start()
  M.retry = hs.timer.doEvery(COOLDOWN / 2, retryTick)

  local front = hs.application.frontmostApplication()
  if front and front:bundleID() == BUNDLE then startTap() end

  dbg("=== ppt-thumb-zoom 준비 (탭은 PPT 최전면일 때만 생성) ===")
  return M
end

function M.stop()
  stopTap()
  if M.retry then M.retry:stop() M.retry = nil end
  if M.watcher then M.watcher:stop() M.watcher = nil end
end

return M
