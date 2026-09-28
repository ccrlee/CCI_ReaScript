-- @noindex

local  DEBUG = true
local STATE = -1
local ITEMS = {}        --List of Items Key = Base 1 Index; Value = MediaItem
local REGIONS = {}
local ALIGNMENT = {}
local TRACKS = {}
local START_TIME
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
    if type(tableVar) == "table" then
        local parts = {}
        for k, v in pairs(tableVar) do
            table.insert(parts, string.format("[%s] = %s", SerializeTable(k), SerializeTable(v)))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return string.format("%q", tableVar)
    end
end

function DeserializeTable(str)
    local ret, err = load("return " .. str)
    if ret then return ret() end
    reaper.ReaScriptError("!" .. err)
end

function GetState()
    local is_new, scriptname, section, command, mode, resolution, val, context = reaper.get_action_context()

    STATE = reaper.GetToggleCommandStateEx(section, command)
end

function UpdateState()
    local is_new, scriptname, section, command, mode, resolution, val, context = reaper.get_action_context()

    local state = reaper.GetToggleCommandStateEx(section, command)
    if state ~= 1 then
        STATE = 1
    else
        STATE = 0
    end
    reaper.SetToggleCommandState(section, command, STATE)
    reaper.RefreshToolbar2(section, command)
end

function SetSettings()
    local ret, data = reaper.GetUserInputs(
                        "VOFX Aligner Settings", --Title
                        1, --Number of Inputs from User
                        "Time (-1 for Playhead)", -- Row Title Values (CSV)
                        "-1" -- Default Values (CSV)
                    )
    if ret then
        SETTINGS.destination = data[1]
    end
end

function GetItems()
    local earliestItem = -1
    local latestItem = -1


    local num_items = reaper.CountSelectedMediaItems(0)
    if num_items == 0 then reaper.ReaScriptError("!No Items are Selected!") end
    local items = {}
    for i = 0, num_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local r, itemGUID = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)

        local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if position < earliestItem or earliestItem == -1 then
            earliestItem = position
        end
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        local endPos = position + length
        if endPos > latestItem or latestItem == -1 then
            latestItem = endPos
        end

        items[itemGUID] = {start = position, stop = position + length}

    end
    ITEMS = items

    local num_regions = reaper.GetNumRegionsOrMarkers( 0 )
    for i = 0, num_regions - 1 do
        local region = reaper.GetRegionOrMarker( 0, i, "")
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

    --ALIGNMENT Key = Region GUID; Value = Table of item GUIDs

    local track = reaper.GetSelectedTrack( 0, 0 )
    if track == nil then
        reaper.ReaScriptError("!No Track is selected.")
        return
    end
    local trackIdx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

    local i = 0
    local startTime = -1
    if tonumber(SETTINGS.destination) < 0 then
        startTime = reaper.GetCursorPosition()
    else
        startTime = tonumber(SETTINGS.destination)
    end
    START_TIME = startTime

    local regionColor = reaper.ColorToNative(255, 255, 0) + 0x1000000
    local tempRegion = reaper.AddRegionOrMarker(0, false, startTime, 0, "TEMP: VOFX Align", 999999, regionColor)
    local _, tempGUID = reaper.GetSetRegionOrMarkerInfo_String( 0, tempRegion, "GUID", "", false )
    for region, items in pairs(ALIGNMENT) do
        local newTrackIdx = i + trackIdx
        reaper.InsertTrackAtIndex(newTrackIdx, true)
        local newTrack = reaper.GetTrack(0, newTrackIdx)
        reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", string.format("[VOFX] %s", REGIONS[region].name), true)
        local r, tguid = reaper.GetSetMediaTrackInfo_String(newTrack, "GUID", "", false)

        TRACKS[tguid] = region

        local regionStart = REGIONS[region].start
        for _, itemGUID in ipairs(items) do
            local item = reaper.BR_GetMediaItemByGUID( 0, itemGUID )
            reaper.MoveMediaItemToTrack( item, newTrack )
            reaper.SetMediaItemInfo_Value(item, "D_POSITION", startTime + (ITEMS[itemGUID].start - regionStart))
        end
        i = i + 1
    end
    reaper.SetProjExtState(0, "VOFX_Align", "Edit_Point", tostring(START_TIME))
    reaper.SetProjExtState(0, "VOFX_Align", "Tracks_Alignment", SerializeTable(TRACKS))
    local r, guid = reaper.GetSetMediaTrackInfo_String(track, "GUID", "", false)
    reaper.SetProjExtState(0, "VOFX_Align", "Edit_Track", guid)
    reaper.SetProjExtState(0, "VOFX_Align", "Temp_Region", tempGUID)
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)


GetState()

if STATE ~= 1 then
    GetItems()
else
    local stateValues = {}
    local count = 0
    local i = 0
    while true do
        local exists, key, value = reaper.EnumProjExtState(0, "VOFX_Align", i)
        if not exists then break end
        stateValues[key] = value
        count = count + 1
        i = i + 1
    end

    if count < 4 then
        reaper.ReaScriptError("!State Recall Failed! Found " .. count .. " keys")
        return
    end
    if stateValues["TRACKS_ALIGNMENT"] ~= nil then
        local value = stateValues["TRACKS_ALIGNMENT"]
        TRACKS = DeserializeTable(value)

        local numSelected = reaper.CountSelectedMediaItems(0)
        if numSelected > 0 then
            reaper.Main_OnCommand(40289, 0)
        end

        local editTrack
        if stateValues["EDIT_TRACK"] ~= nil then
            editTrack = reaper.BR_GetMediaTrackByGUID( 0, stateValues["EDIT_TRACK"] )
        end

        for trackGUID, regionGUID in pairs(TRACKS) do
            local track = reaper.BR_GetMediaTrackByGUID( 0, trackGUID )
            local region = reaper.GetRegionOrMarker( 0, -1, regionGUID )
            local items = {}
            local numItems = reaper.CountTrackMediaItems(track)
            local locationZero = 0
            for i = 0, numItems - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                local itemTime = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                table.insert(items, {item, itemTime})
            end
            
            local markerTime = 0
            if stateValues["EDIT_POINT"] ~= nil then
                markerTime = tonumber(stateValues["EDIT_POINT"]) or 0
            end

            local offset = reaper.GetRegionOrMarkerInfo_Value(0, region, "D_STARTPOS") - markerTime

            for _,set in pairs(items) do
                local item = set[1]
                local time = set[2]

                reaper.SetMediaItemInfo_Value(item, "D_POSITION", time + offset)
                reaper.MoveMediaItemToTrack(item, editTrack)
            end
            reaper.DeleteTrack( track )
        end
        if stateValues["TEMP_REGION"] ~= nil then
                local tempGUID = stateValues["TEMP_REGION"]
                local tempMarker = reaper.GetRegionOrMarker(0, -1, tempGUID)
                local tempIdx = reaper.GetRegionOrMarkerInfo_Value(0, tempMarker, "I_NUMBER")
                reaper.DeleteProjectMarker(0, tempIdx, false)
            else
                reaper.ReaScriptError("We could not delete the temp marker, please do so manually.")
            end
    else
        if key ~= nil then reaper.ReaScriptError("!State Error!\n"..tostring(exists).."\n"..key.."\n"..value)
        else reaper.ReaScriptError("!State Error!\n"..tostring(exists).."\n")
        end
        
    end
end

UpdateState()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("VOFX Align", -1)



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