--[[
description: Resizing regions to selected item(s)
author: William N. Lowe
version: 2.0
changelog:
    2.0
    # Initial reapack integration
]]
numItems = reaper.CountSelectedMediaItems(0)
allItems = {}

for i = 0, numItems do
    allItems[i] = reaper.GetSelectedMediaItem(0, i)
end

ret, marks, regs = reaper.CountProjectMarkers(0)
beginning =  reaper.GetMediaItemInfo_Value( allItems[0], "D_POSITION" )
last =  reaper.GetMediaItemInfo_Value( allItems[numItems - 1], "D_POSITION" ) + reaper.GetMediaItemInfo_Value( allItems[numItems -1], "D_LENGTH" )
for i = 0, (regs + marks) do
    ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(i)
    if isr and regPos <= beginning and regEnd >= last then
        reaper.SetProjectMarker(MarInx, true, beginning, last, regName)
    end
end