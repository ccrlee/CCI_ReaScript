--[[
 * ReaScript Name: RL_CreatePreFaderSend
 * Author: Roc Lee
 * Licence: GPL v3
 * REAPER: 6.78
 * Extensions: None
 * Version: 1.0
--]]
 
--[[
 * Changelog:
 * v1.0 (2023-04-14)
 	+ Initial Release
--]]

function Msg (param)
    reaper.ShowConsoleMsg(tostring (param).."\n")
end

-- wait for input or cancel
retvals_csv = ""
_, retvals_csv = reaper.GetUserInputs("Destination Track", 1, "", retvals_csv)


destTrack = reaper.GetTrack(0, retvals_csv-1)
tracks = reaper.CountSelectedTracks(0)
for i=0, tracks-1 do
    sourceTrack = reaper.GetSelectedTrack(0, i)
    newID = reaper.CreateTrackSend(sourceTrack, destTrack)
    reaper.SetTrackSendInfo_Value(sourceTrack, 0, newID, "I_SENDMODE", 1)
end