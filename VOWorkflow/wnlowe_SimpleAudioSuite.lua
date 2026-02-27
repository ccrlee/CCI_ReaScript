-- @noindex
-- For single or multiple item Audio Suiting with a track called AudioSuite
-- V 1.1
-- By William N. Lowe
-- wnlsounddesign.com
----------------------------------------------------------------
----------------------------------------------------------------
-- Release Notes
----------------------------------------------------------------
----------------------------------------------------------------
--[[
    V1.1:
    [x] Configure for multiple items at once
]] -------------------------------------------------------------
----------------------------------------------------------------
-- FUNCTIONS
----------------------------------------------------------------
----------------------------------------------------------------
-- A Helper function that finds the track called AudioSuite
function FindAStrack()
    -- Adapted from "Pro Tools PLUS Sub Project With Video Track"
    local tracks = reaper.CountTracks(0)
    local i = 0
    while i < tracks do
        local tr = reaper.GetTrack(0, i)
        local retval, trackname = reaper.GetSetMediaTrackInfo_String(tr,
                                                                     "P_NAME",
                                                                     "something",
                                                                     false)
        trackname = string.upper(trackname)
        if trackname == "AUDIOSUITE" then
            return tr
        else
            if trackname == "AUDIO SUITE" then
                return tr
            else
                return 1
            end
        end
    end
end

-- Collects all necessary information on items and their corresponding home track to run the process
function GetInformation()
    -- Initiates Tables
    ItemList = {}
    TrackList = {}
    -- Collect IDs of all selected Media Items
    for C = 0, reaper.CountSelectedMediaItems(0) - 1 do
        ItemList[C] = reaper.GetSelectedMediaItem(0, C)
        -- Collects Item's corresponding tracks
        TrackList[C] = reaper.GetMediaItem_Track(ItemList[C])
    end
end

-- Moves items to AudioSuite track, processes the FX in a new take, returns to original position
function RunAudioSuite()
    -- Use FindAStrack helper function to find the track called AudioSuite
    AudioSuite = FindAStrack()
    -- Make sure there is one
    if AudioSuite == 1 then
        reaper.ShowMessageBox("No Audio Suite Track!!", "Error", 0)
        return
    end
    for i = 0, #ItemList do
        -- Move the item to the Audio Suite track and select it
        reaper.MoveMediaItemToTrack(ItemList[i], AudioSuite)
        reaper.SetMediaItemSelected(ItemList[i], true)
        -- Process the Media Item
        reaper.Main_OnCommand(40361, 0)
        -- Return the Media Item and deselect it
        reaper.MoveMediaItemToTrack(ItemList[i], TrackList[i])
        reaper.SetMediaItemSelected(ItemList[i], false)
    end
end

----------------------------------------------------------------
----------------------------------------------------------------
-- Main
----------------------------------------------------------------
----------------------------------------------------------------

-- Make sure there are items selected
if reaper.CountSelectedTracks(0) > 0 then
    -- Makes sure this is considered all one action in the undo menu
    reaper.Undo_BeginBlock()
    GetInformation()
    -- Deselect all media items
    reaper.SelectAllMediaItems(0, false)
    RunAudioSuite()
    -- Reselect the media items
    for i = 0, #ItemList do reaper.SetMediaItemSelected(ItemList[i], true) end
    reaper.Undo_EndBlock("William Lowe Audio Suite Action", 0)
else
    reaper.ShowMessageBox("No items selected!", "Error", 0)
end

----------------------------------------------------------------
----------------------------------------------------------------
-- NOTES
----------------------------------------------------------------
----------------------------------------------------------------
--[[
    [x] Configure for multiple items at once
    [] Maintaining track channels/option
]]
