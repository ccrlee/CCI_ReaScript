--[[
Description: Project Arkansas VO Pipeline
Version: 1.5.2
Author: William N. Lowe
Provides:
    [main] wnlowe_noItemOverrun.lua
]]

----------------------------------------------------------
----------------------------------------------------------
--HELPERS
----------------------------------------------------------
----------------------------------------------------------
function Msg(variable)
    dbug = false
    if dbug then reaper.ShowConsoleMsg(tostring (variable).."\n") end
end

function GetRenderTrack()
    local ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(ParentRegion)
    return  reaper.EnumRegionRenderMatrix( 0, MarInx, 0 )
end

numItems = reaper.CountSelectedMediaItems(0)
allItems = {}
fileName = ""
for i = 0, numItems do
    allItems[i] = reaper.GetSelectedMediaItem(0, i)
end

ret, marks, regs = reaper.CountProjectMarkers(0)
beginning =  reaper.GetMediaItemInfo_Value( allItems[0], "D_POSITION" )
last =  reaper.GetMediaItemInfo_Value( allItems[numItems - 1], "D_POSITION" ) + reaper.GetMediaItemInfo_Value( allItems[numItems - 1], "D_LENGTH" )
number = nil
_number = nil
letter = false

-- for i = 0, regs + marks do
--     ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(i)
--     if isr and regPos <= beginning and regEnd >= last then
--         fileName = tostring(regName)
--         number = string.match(fileName, "_(%d+)")
--         _number = string.match(fileName, "_(%d+)_")
--         if number ~= nil and _number == nil then letter = true end
--         break
--     end
-- end
relReg = {}
for i = 0, (regs + marks) do
    ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(i)
    selection = 0
    if isr and regPos <= beginning and regEnd >= last then
        selection = selection + 1
        --table.insert(relReg, i)    --reaper.SetProjectMarker(MarInx, true, beginning, last, regName)
    end
    if isr and regPos >=beginning and regPos <= last then
        selection = selection + 1
    end
    if isr and regEnd >= beginning and regEnd <= last then
        selection = selection + 1
    end
    if selection > 0 then table.insert(relReg, i) end
end
if #relReg > 1 then
    ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(relReg[1])
    compStart = math.abs(regPos - beginning)
    compEnd = math.abs (regEnd - last)
    compTotal = compStart + compEnd
    choice = 1
    for i = 2, #relReg do
        ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(relReg[i])
        curStart = math.abs(regPos - beginning)
        curEnd = math.abs (regEnd - last)
        curTotal = curStart + curEnd
        if curTotal < compTotal then 
            choice = i
            compTotal = curTotal
            compStart = curStart
            compEnd = curEnd
        end
    end
    ParentRegion = relReg[choice]
else
    ParentRegion = relReg[1]
end

ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(ParentRegion)
FileName = tostring(regName)
Msg(fileName)
-- number = string.match(fileName, "_(%d+)")
-- _number = string.match(fileName, "_(%d+)_")
-- if number ~= nil and _number == nil then letter = true end
-- if not letter then
--     local response = reaper.ShowMessageBox( "You would like numbers as the suffix?", "Select Suffix Type", 4 )
--     Msg(response)
--     if response == 7 then letter = true end
-- else
--     local response = reaper.ShowMessageBox( "You would like letters as the suffix?", "Select Suffix Type", 4 )
--     Msg(response)
--     if response == 6 then letter = true end
-- end
-- Msg(letter)
ltStart, ltEnd = reaper.GetSet_LoopTimeRange( true, false, regEnd + 0.1, regEnd + 0.1 + #allItems, false )
reaper.Main_OnCommand(40200, 0) -- Time selection: Insert empty space at time selection (moving later items)

for j = #allItems, 0, -1 do
    local _start =  reaper.GetMediaItemInfo_Value( allItems[j], "D_POSITION" )
    reaper.SetMediaItemInfo_Value( allItems[j], "D_POSITION", _start + j )
end

RenderTrack = GetRenderTrack()
markRegs = regs + marks
-- if letter then
--     for j = 0, #allItems do
--         local _start =  reaper.GetMediaItemInfo_Value( allItems[j], "D_POSITION" )
--         local _end =  reaper.GetMediaItemInfo_Value( allItems[j], "D_LENGTH" ) + _start
--         local newMarker = reaper.AddProjectMarker( 0, true, _start, _end, string.format("%s_%s", fileName, string.char(64 + j + 1)), markRegs + j )
--         reaper.SetProjectMarker(MarInx, true, beginning, _end, regName)
--         if RenderTrack ~= nil then reaper.SetRegionRenderMatrix( 0, newMarker, RenderTrack, 1 ) end
--     end
-- else
for j = 0, #allItems do
    local _start =  reaper.GetMediaItemInfo_Value( allItems[j], "D_POSITION" )
    local _end =  reaper.GetMediaItemInfo_Value( allItems[j], "D_LENGTH" ) + _start
    if j == 0 then
        Msg(FileName)
        newMarker = reaper.AddProjectMarker( 0, true, _start, _end, FileName, markRegs + j )
    else
        local baseName, suffix = FileName:match("(.+)(_enus.+)")
        newMarker = reaper.AddProjectMarker( 0, true, _start, _end, baseName .. "_v" .. j .. suffix, markRegs + j )
    end
    reaper.SetProjectMarker(MarInx, true, beginning, _end, regName)
    if RenderTrack ~= nil then reaper.SetRegionRenderMatrix( 0, newMarker, RenderTrack, 1 ) end
end
-- end

reaper.DeleteProjectMarker( 0, MarInx, true )