local  DEBUG = true
local STATE = -1
local ITEMS = {}        --List of Items Key = Base 1 Index; Value = MediaItem
local REGIONS = {}
local ALIGNMENT = {}
local SETTINGS = {
    destination = -1
}

function Msg(msg)
    if DEBUG then reaper.ShowConsoleMsg(tostring(msg) .. "\n")end
end

function RetCheck(ret, msg)
    if ret == true then return end

    if msg == nil or msg == "" then
        msg = "!This script ran into a return error."
    end
    reaper.ReaScriptError(msg)
end

function SerializeTable(tableVar)

end

function DeserializeTable(str)

end

function UpdateState()
    local is_new, scriptname, section, command, mode, resolution, val, context = reaper.get_action_context()

    local state = reaper.GetToggleCommandStateEx(section, command)

    if state ~= 1 then
        STATE = 1
    else
        STATE = 0
    end
end

function SetSettings()
    local ret, data = reaper.GetUserInputs(
                        "VOFX Aligner Settings", --Title
                        1, --Number of Inputs from User
                        "Time (-1 for Playhead)", -- Row Title Values (CSV)
                        "-1" -- Default Values (CSV)
                    )
    if ret then Msg(data) end
end

function GetItems()
    local earliestItem = -1
    local latestItem = -1


    local num_items = reaper.CountSelectedMediaItems(0)
    local items = {}
    for i = 1, num_items do
        local item = reaper.GetSelectedMediaItem(0, i)

        local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if position < earliestItem or earliestItem == -1 then
            earliestItem = position
        end
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        local endPos = position + length
        if endPos > latestItem or latestItem == -1 then
            latestItem = endPos
        end

        items[item] = {start = position, stop = position + length}

    end
    ITEMS = items

    local num_regions = reaper.GetNumRegionsOrMarkers( 0 )
    for i = 1, num_regions do
        local region = reaper.GetRegionOrMarker( 0, i)
        local isRegion = reaper.GetRegionOrMarkerInfo_Value(0, region, "B_ISREGION" )
        if isRegion == 1 then
            local ret, guid = reaper.GetSetRegionOrMarkerInfo_String( 0, region, "GUID", "", false )
            RetCheck(ret)
            local ret, rName = reaper.GetSetRegionOrMarkerInfo_String(0, region, "P_NAME", "", false)
            RetCheck(ret)
            local position = reaper.GetRegionOrMarkerInfo_Value( 0, region, "D_STARTPOS" )
            local endPos = reaper.GetRegionOrMarkerInfo_Value(0, region, "D_ENDPOS")
            if position > earliestItem - 1 and endPos < latestItem + 5 then
                REGIONS[guid] = {name = rName, start = position, stop = endPos}
            end
        end
    end

    for mi, item in pairs(ITEMS) do
        for guid, region in pairs(REGIONS) do
            if region.start <= item.start and item.stop <= region.stop then
                ALIGNMENT[guid] = ALIGNMENT[guid] or {}
                table.insert(ALIGNMENT[guid], mi)
            end
        end
    end

    local track = reaper.GetSelectedTrack( 0, 0 )
    local trackIdx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

    local i = 1
    for region, items in pairs(ALIGNMENT) do
        local newTrackIdx = i + trackIdx
        reaper.InsertTrackAtIndex(newTrackIdx, true)
        local newTrack = reaper.GetTrack(0, newTrackIdx)
        reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", string.format("[VOFX] %s", region.name), true)

        local startTime = -1
        if SETTINGS.destination < 0 then
            startTime = reaper.GetCursorPosition()
        else
            startTime = SETTINGS.destination
        end

        local originReference
        for j, item in ipairs(items) do
            local offset
            reaper.MoveMediaItemToTrack( item, newTrack )
            if j == 1 then
                originReference = item.start
            end

            offset = item.start - originReference

            reaper.SetMediaItemInfo_Value(item, "D_POSITION", startTime + offset)

        end
    end

end

SetSettings()





-- local ret = reaper.GetSetMediaItemInfo_String(item, "P_EXT:VOFX_POSITION", tostring(position), true)
        -- if ret == false then
        --     reaper.ReaScriptError(
        --         string.format(
        --             "!Your item %s is not writing correctly",
        --             reaper.GetSetMediaItemTakeInfo_String(
        --                 reaper.GetActiveTake(item),
        --                 "P_NAME",
        --                 "",
        --                 false
        --             )
        --         )
        --     )
        -- end