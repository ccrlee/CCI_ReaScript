-- @description Top Tail Gui
-- @author Roc Lee
-- @version 0.5

local debug = false

function Msg (param)
    if debug then
      reaper.ShowConsoleMsg(tostring (param).."\n")
    end
end


function ReaperNamedCommand(command)
    reaper.Main_OnCommand(reaper.NamedCommandLookup(command), 0)
end


function convertToLogarithmic(linearValue)
    local minimumLinearValue = 0
    local maximumLinearValue = 100
    local minimumLogarithmicValue = -60
    local maximumLogarithmicValue = 12

    local logarithmicValue = (math.log(linearValue, 10) - math.log(minimumLinearValue, 10)) / (math.log(maximumLinearValue, 10) - math.log(minimumLinearValue, 10)) * (maximumLogarithmicValue - minimumLogarithmicValue) + minimumLogarithmicValue

    return logarithmicValue
end

local path = reaper.GetResourcePath()..'/Scripts/RL Scripts/RL_HelperFunctions/'

-- Check if config.ini file exists
local file = io.open(path.."FileTest.ini", "r")
Msg(file)
if file == nil then
  -- File doesn't exist, create it and initialize variables
  file = io.open(path.."FileTest.ini", "w")
  file:write("min=-54\n")
  file:write("max=0\n")
  file:close()
end

-- Read variables from config.ini file
local min_val = 0
local max_val = 0
for line in io.lines(path.."FileTest.ini") do
--   local key, value = line:match("^(%w+)=(%d+)$")
  local key, value = line:match("^(%w+)=(%g+)$")
  Msg(key)
  Msg(value)
  if key == "min" then
    -- value.match() <------------- need to check for negative and then deal with that
    -- val = value.match("(%d+)$")
    min_val = tonumber(value)
  elseif key == "max" then
    max_val = tonumber(value)
  end
end

-- Do something with the variables
Msg("min_val = " .. min_val)
Msg("max_val = " .. max_val)

function WriteConfigValues (low, high)
    local file = io.open(path.."FileTest.ini", "r")
    Msg(file)
    if file == nil then
    -- File doesn't exist, create it and initialize variables
    file = io.open(path.."FileTest.ini", "w")
    file:write("min=-54\n")
    file:write("max=0\n")
    file:close()
    elseif file ~= nil then
    file:close()
    file = io.open(path.."FileTest.ini", "w")
    file:write("min="..low.."\n")
    file:write("max="..high.."\n")
    file:close()
    Msg(low)
    end
end

----GUI -------------

package.path = reaper.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
local rtk = require("rtk")
local win = rtk.Window{w=400, h=200}

local box = rtk.VBox{spacing=5, bpadding=10}
win:add(box)

local hbox = box:add(rtk.HBox{spacing=5, valign='center'})
local min_txt = hbox:add(rtk.Text{tostring(min_val), w=25})
local slider = hbox:add(rtk.Slider{value={min_val, max_val}, step=1, min=-60, max=12})
-- local slider = hbox:add(rtk.Slider{value={min_val, max_val}, step=1, min=0, max=100})
local max_txt = hbox:add(rtk.Text{tostring(max_val), w=25})
slider.onchange = function(self)
    min_txt:attr('text',  self.value[1])
    max_txt:attr('text', self.value[2])

    if self.value[1] < 0 then
        math.abs(self.value[1])
    end

    WriteConfigValues(self.value[1], self.value[2])
end

local runButton = box:add(rtk.Button{label='Run Top Tail'})
runButton.onclick = function()
        reaper.PreventUIRefresh(1)

        ReaperNamedCommand('_SWS_SAVEALLSELITEMS1')
        ReaperNamedCommand('_XENAKIOS_SETITEMFADES')
        local numItems = reaper.CountSelectedMediaItems(0)
        -- Msg(numItems)
            for i = 0, numItems-1 do
                reaper.Undo_BeginBlock()
                reaper.GetSelectedMediaItem(0, i)
                -- ReaperNamedCommand('_RS7c61312956f0c64e9e52e2ba705421698a6eecdf') -- Top and tail first item
                ReaperNamedCommand('_RSbf40684bf8b866d5145574eda4e4cb7c142cf42c')
                ReaperNamedCommand('_RS0d5c6f149848db770ba875cd02eac54f3de22d59') -- Deslect First Item
                reaper.Undo_EndBlock('Top and Tail Item '..i, 0)
            end
        ReaperNamedCommand('_SWS_RESTALLSELITEMS1')
        reaper.PreventUIRefresh(-1)
    end


-------------------------


-- Show the window
win:open{align='center'}


