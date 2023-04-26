-- @description Helper Functions for Top Tail Script 2
-- @author Roc Lee
-- @version 0.5

dofile(reaper.GetResourcePath()..'/Scripts/CCI/HelperFunctions/RL_SampleBufferReader.lua' )
local path = reaper.GetResourcePath()..'/Scripts/CCI/HelperFunctions/'


local file = io.open(path.."FileTest.ini", "r")

if file == nil then return end
local threshold = -52.0
local topThreshold = -48.0

for line in io.lines(path.."FileTest.ini") do
--   local key, value = line:match("^(%w+)=(%d+)$")
  local key, value = line:match("^(%w+)=(%g+)$")
--   Msg(key)
--   Msg(value)
  if key == "min" then
    -- value.match() <------------- need to check for negative and then deal with that
    -- val = value.match("(%d+)$")
    threshold = tonumber(value)
  elseif key == "max" then
    topThreshold = tonumber(value)
  end
end


------INIT Variables
local window_size = 1 -- in seconds
local samplerate = tonumber(reaper.format_timestr_pos( 1-reaper.GetProjectTimeOffset( 0,false ), '', 4 )) -- get sample rate obey project start offset
local bufferSize = math.ceil(window_size * samplerate)
local numChannels = 1
local sampleReadBuffer = reaper.new_array(bufferSize)

local collected_samples = {}
local read_pos = 0
local write_pos = 0

local endThreshold = threshold
local endTopThreshold = topThreshold

item = reaper.GetSelectedMediaItem(0, 0)
if not item then return end
local take = reaper.GetActiveTake(item)
local item_pos, item_len, boundary_start, boundary_end = GetTakeBoundaries(take)
ReadTakeSamples(take, window_size, samplerate, numChannels, read_pos, bufferSize, collected_samples)

local samplePos = 0
local newTop = 0
local newEnd = 0

function processSamples(readPos, table, jumptToEnd)
    local offset = 0
    if readPos >= #table then return 0 end
    
    for i = readPos, #table do

        local mag2Db = 20 * math.log(table[i], 10)      -- value at sample position
        offset = i                                      -- sample position in table
        
        if mag2Db > threshold and mag2Db < topThreshold then break end
    end
    
    samplePos = offset / samplerate
    newTop = samplePos+item_pos

    --process backwards
    if jumptToEnd == true then 
        for i = #table, 1, -1 do
            local mag2Db = 20 * math.log(table[i], 10)
            offset = i    
            if mag2Db > endThreshold and mag2Db < endTopThreshold then break end
        end

        samplePos = offset / samplerate
        newEnd = samplePos+item_pos
    end 
end


processSamples (1, collected_samples, true)
reaper.BR_SetItemEdges( item, newTop, newEnd )
----------------------------