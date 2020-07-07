--------------------------------------------------
--------------------------------------------------
--------- VTX LUA for SMARTAUDIO 2.0 -------------
------------Craig Fitches 07/07/2020 -------------
----------------v 0.1 Alpha ----------------------
--------------------------------------------------
-- PLEASE DONATE FOR FURTHER DEVELOPMENT ---------
-- https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=DGXD5S9FAUUUJ&source=url
---------------------------------------------------
-----------------HARDWARE------------------
-- EACHINE TX805 VTX
-- MATEKSYS 765

-- Next Build
-- 1. Support other SmartAudio versions
-- 2. Get Settings from SmartAudio
-- 3. Enable / Disable Auto mode via radio channel

-- Prerequisits ----------------------------------
-- 1. Only (currently) works in Ardupilot 4.1
-- 2. FC with 2MB cache for LUA Scripting
-- 3. Currently only works with SmartAudio 2.0

------------ Instructions ------------------------
-- 1. Set serial5 in Ardupilot to protocol 28 (scripting)
-- 2. Setup channel 5(or any but be sure to update the RCchannel 
-- variable below) in RC transmitter with low PWMA 0
-- and High 2000. You can print the _current_pwma to ensure
-- you have the correct values. I used one of the dials for this
-- 3. Attach SmartAudio cable to serial 5 (TX8 on Mateksys 765 WING)
-- 4. Set Half Duplex mode on serial

------- USER PARAMS ------------------------------
local RCchannel = 5 --select the RC channel to use.
local manaulSet = true -- set if you want to manually set
local autoPower = false -- set if you want it to auto set [SIM tested only]
--------------------------------------------------
--------------------------------------------------

local _current_power = 0
local _current_pwma = rc:get_pwm(RCchannel)

-- hexidecimal smart audio 2.0
local channel = {0x00,0x00,0xAA,0x55,0x07,0x01,0x00,0xB8,0x00} -- default
local frequency = {0x00,0x00,0xAA,0x55,0x09,0x02,0x16,0xE9,0xDC,0x00} -- default
local activatePitMode = {0x00,0x00,0xAA,0x55,0x0B,0x01,0x01,0xF8,0x00}
local deactivatePitMode = {0x00,0x00,0xAA,0x55,0x0B,0x01,0x04,0xD3,0x00}
local SMARTAUDIO_V2_COMMAND_POWER_0 = {0x00,0x00,0xAA,0x55,0x05,0x01,0x00,0x6B,0x00}
local SMARTAUDIO_V2_COMMAND_POWER_1 = {0x00,0x00,0xAA,0x55,0x05,0x01,0x01,0xBE,0x00}
local SMARTAUDIO_V2_COMMAND_POWER_2 = {0x00,0x00,0xAA,0x55,0x05,0x01,0x02,0x14,0x00}
local SMARTAUDIO_V2_COMMAND_POWER_3 = {0x00,0x00,0xAA,0x55,0x05,0x01,0x03,0xC1,0x00}


local port = serial:find_serial(0)
if not port then
  gcs:send_text(0, "No Scripting Serial Port")
return
end

port:begin(4800)

---- main update ---
function update ()
  _current_pwma = rc:get_pwm(RCchannel)
  if manaulSet == true then
    setPower(_current_pwma)
  elseif autoPower == true then
    autoPowerMode()
  end
  return update, 100
end
---- end main update ---

function setPower(pwma)
  if pwma <= 1250 and _current_power ~= 0 then 
    updateSerial(activatePitMode)
   _current_power = 0
   gcs:send_text(0, "VTX PWR Pit" .. _current_power)
  elseif pwma > 1250 and pwma < 1500 and _current_power ~= 1 then
    updateSerial(SMARTAUDIO_V2_COMMAND_POWER_1)
   _current_power = 1
   gcs:send_text(0, "VTX PWR 1" .. _current_power)
  elseif pwma >= 1500 and pwma <= 1750 and _current_power ~= 2 then
    updateSerial(SMARTAUDIO_V2_COMMAND_POWER_2)
    _current_power = 2
    gcs:send_text(0, "VTX PWR 2" .. _current_power)
  elseif pwma > 1750 and _current_power ~= 3 then
    updateSerial(SMARTAUDIO_V2_COMMAND_POWER_3)
    _current_power = 3
    gcs:send_text(0, "VTX PWR 3" .. _current_power)
  end
end

function updateSerial(value)
  for count = 1, #value do
    --gcs:send_text(0, "Writing "..value[count]) debugging
    port:write(value[count])
  end
end


function autoPowerMode()
  local home = ahrs:get_home()
  local position = ahrs:get_position()
  local dist = 0
  if home and position then
    dist = position:get_distance(home)
    --gcs:send_text(0, "Distance from home " .. dist) debug
    if dist <= 200 and _current_power ~= 1 then
      gcs:send_text(0, "VTX 1")
      updateSerial(SMARTAUDIO_V2_COMMAND_POWER_1)
      _current_power = 1
    elseif dist > 200 and dist <= 600 and _current_power ~= 2 then
      gcs:send_text(0, "VTX 2")
      updateSerial(SMARTAUDIO_V2_COMMAND_POWER_2)
      _current_power = 2
    elseif dist > 600 and _current_power ~= 3 then
      gcs:send_text(0, "VTX 3")
      updateSerial(SMARTAUDIO_V2_COMMAND_POWER_3)
      _current_power = 3
    end
  else
    gcs:send_text(0, "Cannot get home or position")
  end
end

------- debugging -----
local log_data = {}
local term_number = 0
local term_max_len = 10

function readSerial()
 local n_bytes = port:available()
 while n_bytes > 0  and term_number <= term_max_len do
    local read = port:read()
    log_data[term_number] = read
    gcs:send_text(0,"Reading: " .. read)
    term_number = term_number + 1
   end
 if next(log_data) ~= nil then
    gcs:send_text(0,"Reading: " .. table.unpack(log_data))
    log_data = {}
 end
end


return update, 100

