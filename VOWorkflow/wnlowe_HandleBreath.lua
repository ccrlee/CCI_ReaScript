-- @description Clip Gain Drop by specified ammount based on time selection
-- @author William N. Lowe
-- @version 1.01

-- local VSDEBUG = dofile("C:\\Users\\ccuts\\.vscode\\extensions\\antoinebalaine.reascript-docs-0.1.15\\debugger\\LoadDebug.lua")

local REFERENCE_VALUE = 716.217
local DB_DROP = 10

function DBToEnvelopeValue(envelope, target_db)
  -- For 0dB, return reference directly
  if math.abs(target_db) < 0.01 then
    return REFERENCE_VALUE
  end
  
  local min_val = target_db < 0 and 0 or REFERENCE_VALUE
  local max_val = target_db < 0 and REFERENCE_VALUE or 10000
  local tolerance = 0.1  -- dB tolerance
  
  for i = 1, 50 do
    local mid_val = (min_val + max_val) / 2
    local formatted = reaper.Envelope_FormatValue(envelope, mid_val)
    local current_db = tonumber(formatted:match("[-0-9.]+"))

    if not current_db then return 0 end

    if math.abs(current_db - target_db) < tolerance then
      return mid_val
    elseif current_db < target_db then
      min_val = mid_val
    else
      max_val = mid_val
    end
  end
  
  return (min_val + max_val) / 2
end

function EnvelopeValueToDB(envelope, raw_value)
  local formatted = reaper.Envelope_FormatValue(envelope, raw_value)
  return tonumber(formatted:match("[-0-9.]+"))
end


local startT, endT = reaper.GetSet_LoopTimeRange(false, false, 0, 0, true)
if not startT or endT - startT <= 0 then return end
local item = reaper.GetSelectedMediaItem(0, 0)
if not item then return end
local take = reaper.GetActiveTake(item)
local envelope = reaper.GetTakeEnvelopeByName(take, "Volume")
local OffsetStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

-- Evaluate at project time
local retval, startValue = reaper.Envelope_Evaluate(envelope, startT, 0, 0)
if not retval then return end

local retval, endValue = reaper.Envelope_Evaluate(envelope, endT, 0, 0)
if not retval then return end

-- Convert to dB, adjust, and convert back
local startDB = EnvelopeValueToDB(envelope, startValue)
local endDB = EnvelopeValueToDB(envelope, endValue)

local fadeDownDB = startDB - DB_DROP  -- reduce by 10dB

-- Insert points using item-relative time
local startTime = startT - OffsetStart
local endTime = endT - OffsetStart

reaper.InsertEnvelopePoint(envelope, startTime, startValue, 0, 0, false, true)
reaper.InsertEnvelopePoint(envelope, startTime + .05, DBToEnvelopeValue(envelope, fadeDownDB), 0, 0, false, true)
reaper.InsertEnvelopePoint(envelope, endTime - .05, DBToEnvelopeValue(envelope, fadeDownDB), 0, 0, false, true)
reaper.InsertEnvelopePoint(envelope, endTime, endValue, 0, 0, false, true)
