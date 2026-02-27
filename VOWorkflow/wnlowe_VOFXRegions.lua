-- @noindex
function Msg(variable)
    return
end

numItems = reaper.CountSelectedMediaItems(0)
allItems = {}
fileName = ""
for i = 0, numItems do
    allItems[i] = reaper.GetSelectedMediaItem(0, i)
end
Msg(numItems)
Msg(allItems)
ret, marks, regs = reaper.CountProjectMarkers(0)
beginning =  reaper.GetMediaItemInfo_Value( allItems[0], "D_POSITION" )
last =  reaper.GetMediaItemInfo_Value( allItems[numItems - 1], "D_POSITION" ) + reaper.GetMediaItemInfo_Value( allItems[numItems - 1], "D_LENGTH" )
Msg(beginning)
Msg(last)
for i = 0, regs + marks do
    ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(i)
    if isr and regPos <= beginning and regEnd >= last then
        fileName = tostring(regName)
        Msg(regName)
        break
    end
end

for j = #allItems, 0, -1 do
    local _start =  reaper.GetMediaItemInfo_Value( allItems[j], "D_POSITION" )
    reaper.SetMediaItemInfo_Value( allItems[j], "D_POSITION", _start + j )
end

markRegs = regs + marks
Msg(markRegs)
Msg(MarInx)
for j = 0, #allItems do
    local _start =  reaper.GetMediaItemInfo_Value( allItems[j], "D_POSITION" )
    local _end =  reaper.GetMediaItemInfo_Value( allItems[j], "D_LENGTH" ) + _start
    reaper.AddProjectMarker( 0, true, _start, _end, string.format("%s_%02d", fileName, j + 1), markRegs + j )
    reaper.SetProjectMarker(MarInx, true, beginning, _end, regName)
end
