-- pinch-probe.lua — 트랙패드 핀치 이벤트에서 "배율 델타"가 실린 필드를 찾는 임시 모듈.
-- 1차 시도에서 배운 것: 핀치는 type=30(magnify) 이 아니라 type=29(gesture) 로 온다.
-- 그런데 커서 이동만 해도 29가 쏟아진다(f110=0/6). 그래서 노이즈를 걸러야 한다.
-- init.lua 에 넣지 말 것. 비상 정지: killall Hammerspoon

local M = {}
local LOG     = os.getenv("HOME") .. "/.hammerspoon/pinch-probe.log"
local MAX_HIT = 40      -- "의미 있는" 이벤트만 이만큼
local MAX_SEC = 600
local LO, HI  = 100, 140  -- 훑어볼 필드 범위

local hits, seen, tap, timer = 0, 0, nil, nil
local function log(s) local f=io.open(LOG,"a") if f then f:write(s.."\n") f:close() end end

local function dump(t, name)
  if type(t) ~= "table" then return end
  local keys = {}
  for k in pairs(t) do keys[#keys+1] = tostring(k) end
  table.sort(keys)
  log("   " .. name .. " keys: " .. table.concat(keys, ", "))
  for _, k in ipairs(keys) do
    local v = t[k]
    if type(v) ~= "table" then log(string.format("     %s = %s", k, tostring(v))) end
  end
end

function M.stop()
  if tap then tap:stop(); tap = nil end
  if timer then timer:stop(); timer = nil end
  log(string.format("-- 정지 (총 %d개 중 %d개 기록) --", seen, hits))
end

function M.start()
  os.remove(LOG)
  log("-- 시작 " .. os.date("%H:%M:%S") .. " — Chrome 에서 핀치 확대/축소 해보세요 --")
  hits, seen = 0, 0

  tap = hs.eventtap.new({ hs.eventtap.event.types.gesture,
                          hs.eventtap.event.types.magnify }, function(e)
    seen = seen + 1
    -- LO..HI 필드를 훑어 0이 아닌 값만 모은다 (순수 산술, AX 호출 없음)
    local nz = {}
    for f = LO, HI do
      local ok, v = pcall(function() return e:getProperty(f) end)
      if ok and type(v) == "number" and v ~= 0 then
        nz[#nz+1] = string.format("f%d=%s", f, tostring(v))
      end
    end
    -- 커서 이동 노이즈로 관측된 필드를 통째로 제외하고 남는 게 있는지만 본다
    local IGNORE = { [101]=true, [107]=true, [110]=true, [115]=true,
                     [116]=true, [117]=true, [123]=true, [132]=true }
    local interesting = {}
    for f = LO, HI do
      if not IGNORE[f] then
        local ok, v = pcall(function() return e:getProperty(f) end)
        if ok and type(v) == "number" and v ~= 0 then
          interesting[#interesting+1] = string.format("f%d=%s", f, tostring(v))
        end
      end
    end
    local only_noise = (#interesting == 0)
    nz = interesting
    if not only_noise and hits < MAX_HIT then
      hits = hits + 1
      log(string.format("#%d type=%d | %s", hits, e:getType(), table.concat(nz, " ")))
      if hits <= 3 then
        local okr, raw = pcall(function() return e:getRawEventData() end)
        if okr and type(raw) == "table" then
          dump(raw.NSEventData, "NSEventData")
          dump(raw.CGEventData, "CGEventData")
        end
      end
      if hits >= MAX_HIT then M.stop() end
    end
    return false
  end)

  tap:start()
  timer = hs.timer.doAfter(MAX_SEC, function() M.stop() end)
  log("탭 활성. " .. MAX_SEC .. "초 후 자동 정지.")
end

return M
