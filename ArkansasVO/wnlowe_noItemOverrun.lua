--@noindex

local item = reaper.GetSelectedMediaItem(0, 0)
local take = reaper.GetActiveTake(item)
local startTime = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
local endTime = startTime + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
local source = reaper.GetMediaItemTake_Source(take)
local sourceLength = reaper.GetMediaSourceLength(source)
if startTime < 0 then reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", 0) end
if endTime - 0.000001 > sourceLength then reaper.SetMediaItemInfo_Value(item, "D_LENGTH", sourceLength - startTime) end