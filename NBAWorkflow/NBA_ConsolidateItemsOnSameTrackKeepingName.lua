-- @noindex
-- @description NBA Consolidate Items on Same Track Keeping Name
-- @author Roc Lee
-- @version 0.9

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

function GlueSelectedItemToTimeSelectionKeepingName(n)
    ReaperNamedCommand(41588) -- glue items expanding to time selection
    t = reaper.GetActiveTake(reaper.GetSelectedMediaItem(0, 0)) -- have to get the glued item
    _, _ = reaper.GetSetMediaItemTakeInfo_String(t, "P_NAME", n, true)
end

-----------------------------------------------------------

reaper.Undo_BeginBlock()
local item = reaper.GetSelectedMediaItem(0, 0)
local t = reaper.GetActiveTake(item)
local name = reaper.GetTakeName(t)
ReaperNamedCommand(40362) -- glue items
SetTimeSelectionToItemRegion(reaper.GetSelectedMediaItem(0, 0))
GlueSelectedItemToTimeSelectionKeepingName(name)
reaper.Undo_EndBlock('Consolidate Items on same track keeping name', 0)
