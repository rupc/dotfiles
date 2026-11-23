-- >>> winkeys: PPT 보조 기능 >>>
-- 로그인 시 자동 실행 등록. 멱등이라 매번 호출해도 안전하다.
-- (없으면 재부팅 후 Hammerspoon 이 안 떠서 기능이 통째로 사라진다 — 2026-08-17 실제로 겪음)
hs.autoLaunch(true)

-- `hs -c "..."` 로 상태를 들여다볼 수 있게 한다 (디버깅에 필수).
require("hs.ipc")

local HOME = os.getenv("HOME")
pptZoom   = dofile(HOME .. "/.hammerspoon/ppt-thumb-zoom.lua").start()   -- 축소판 창 Ctrl+휠
pptRibbon = dofile(HOME .. "/.hammerspoon/ppt-ribbon.lua").start()       -- Cmd+H 코드 (S-H / F-C)
fndTerm   = dofile(HOME .. "/.hammerspoon/finder-iterm.lua").start()     -- Finder ⌃⌘⇧↓ = 현재 폴더에서 iTerm2
pastePlain = dofile(HOME .. "/.hammerspoon/paste-plain.lua").start()     -- Word/PPT Ctrl+Shift+V = 평문 붙여넣기
-- <<< winkeys <<<
