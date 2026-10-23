-- tests/smoke.lua: headless end-to-end test, run by `make test`.
--
-- Mesen's test runner boots the ROM with no window and runs this script at
-- full speed. Rather than peeking at the game's variables, it checks what the
-- player would see: tilemap contents in VRAM plus the PPU's brightness and
-- enabled layers. It walks through every scene, pressing Start where a
-- player would, saves a screenshot of each to $SCREENSHOT_DIR, and exits
-- with 0 on success or 1 on failure.
--
-- Mesen 2 Lua API: https://www.mesen.ca/docs/apireference.html

-- Keep in sync with src/vram.inc (VRAM word addresses) and the Makefile.
local BG1_MAP   = 0x0000
local BG2_MAP   = 0x0400
local LOGO_TILE = 128
local TM_BG1, TM_BG2 = 1, 2

local WAIT_LIMIT = 600  -- frames to wait for any one thing (10 s of game time)

local frame = 0
local held = {}         -- button name -> frames left to hold it

-- Tile number at a tilemap position (the low 10 bits of the entry).
local function tile(map, col, row)
  return emu.read16((map + row * 32 + col) * 2, emu.memType.snesVideoRam) & 0x3FF
end

-- Does the tilemap spell out `text` on one row? The font is loaded so that
-- tile number == ASCII code, so the tilemap can be read back as text.
local function hasText(map, text)
  for row = 0, 27 do
    local chars = {}
    for col = 0, 31 do
      local t = tile(map, col, row)
      chars[#chars + 1] = (t >= 0x20 and t < 0x7F) and string.char(t) or " "
    end
    if table.concat(chars):find(text, 1, true) then return true end
  end
  return false
end

local function hasLogo()
  for row = 0, 27 do
    for col = 0, 31 do
      if tile(BG1_MAP, col, row) >= LOGO_TILE then return true end
    end
  end
  return false
end

-- Display on, full brightness, and the given layers enabled.
local function fullyVisible(layers)
  local s = emu.getState()
  return not s["ppu.forcedBlank"] and s["ppu.screenBrightness"] == 15
     and (s["ppu.mainScreenLayers"] & layers) == layers
end

local function screenshot(name)
  local dir = os and os.getenv("SCREENSHOT_DIR")
  if not dir then return end
  local f = assert(io.open(dir .. "/" .. name .. ".png", "wb"))
  f:write(emu.takeScreenshot())
  f:close()
end

-- Test steps run as a coroutine that yields once per frame.
local function waitFrames(n)
  for _ = 1, n do coroutine.yield() end
end

local function waitUntil(what, condition)
  local start = frame
  while not condition() do
    if frame - start > WAIT_LIMIT then
      error("timed out after " .. WAIT_LIMIT .. " frames waiting for " .. what, 0)
    end
    coroutine.yield()
  end
  print(string.format("ok   frame %4d  %s", frame, what))
end

local function expect(condition, what)
  if not condition then error("expected " .. what, 0) end
  print(string.format("ok   frame %4d  %s", frame, what))
end

local function press(button, frames)
  held[button] = frames
  waitFrames(frames)
end

local test = coroutine.create(function()
  waitUntil("logo faded in", function()
    return hasLogo() and fullyVisible(TM_BG1)
  end)
  screenshot("1-logo")

  waitUntil("title screen faded in, PRESS START visible", function()
    return hasText(BG2_MAP, "PRESS START") and fullyVisible(TM_BG1 | TM_BG2)
  end)
  screenshot("2-title")

  waitFrames(180)
  expect(hasText(BG2_MAP, "PRESS START") and not hasText(BG1_MAP, "hello world"),
         "title screen still waiting after 3 s without input")

  press("start", 4)
  waitUntil("hello screen faded in", function()
    return hasText(BG1_MAP, "well, hello world!") and fullyVisible(TM_BG1)
  end)
  screenshot("3-hello")

  waitFrames(120)
  expect(hasText(BG1_MAP, "well, hello world!") and fullyVisible(TM_BG1),
         "hello screen still showing 2 s later")
end)

-- Feed the held buttons to controller 1 whenever the game reads it.
emu.addEventCallback(function()
  local input = { start = false }
  for button, frames in pairs(held) do
    if frames > 0 then
      input[button] = true
      held[button] = frames - 1
    end
  end
  emu.setInput(input, 0)
end, emu.eventType.inputPolled)

local finished = false
emu.addEventCallback(function()
  if finished then return end
  frame = frame + 1
  local ok, err = coroutine.resume(test)
  if not ok then
    finished = true
    print("FAIL " .. err)
    emu.stop(1)
  elseif coroutine.status(test) == "dead" then
    finished = true
    print("PASS all scenes reached")
    emu.stop(0)
  end
end, emu.eventType.endFrame)
