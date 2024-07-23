function Msg (param)
    if debug then
      reaper.ShowConsoleMsg(tostring (param).."\n")
    end
end

function ReaperNamedCommand(command)
    reaper.Main_OnCommand(reaper.NamedCommandLookup(command), 0)
end

function SetTimeSelectionToItemRegion(take)
    Item_Pos = reaper.GetMediaItemInfo_Value(take, "D_POSITION")
    markeridx, regionidx = reaper.GetLastMarkerAndCurRegion( 0, Item_Pos)
    retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(regionidx)
    reaper.GetSet_LoopTimeRange(true, false, pos, rgnend, false)

end

function GlueItemToTimeSelectionKeepingName(take)
    local t = reaper.GetActiveTake(take)
    local name = reaper.GetTakeName(t)
    ReaperNamedCommand(41588) -- glue items expanding to time selection
    t = reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, 0)) -- have to get the glued item
    _, _ = reaper.GetSetMediaItemTakeInfo_String(t, "P_NAME", name, true)
end

function GetItemSelectionGUIDs(guid_table)
    local numItems = reaper.CountSelectedMediaItems(0)
    for i = 0, numItems-1 do
        guid = reaper.BR_GetMediaItemGUID(reaper.GetSelectedMediaItem(0, i))
        table.insert(guid_table, guid)
    end
end

-----------------------------------------------------------

local guid_table = {}
GetItemSelectionGUIDs(guid_table)

reaper.PreventUIRefresh(1)
ReaperNamedCommand(40289)

for i = 1, #guid_table do
    reaper.Undo_BeginBlock()
    local item = reaper.BR_GetMediaItemByGUID(0, guid_table[i])
    reaper.SetMediaItemSelected(item, true)
    SetTimeSelectionToItemRegion(item)
    GlueItemToTimeSelectionKeepingName(item)
    ReaperNamedCommand(40020) -- clear timeselection for next item
    ReaperNamedCommand(40289) -- clear item selection for next item
    reaper.Undo_EndBlock('Consolidate Item '..i, 0)
end

reaper.PreventUIRefresh(-1)