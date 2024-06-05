-- @description Select Dummy Track
-- @author Roc Lee
-- @version 0.1
function Msg (param)
    reaper.ShowConsoleMsg(tostring (param).."\n")
end

-- // get current selected track

function CreateDummy(total)
    reaper.InsertTrackAtIndex(total-1, true)
    newTrack = reaper.GetTrack(0, total-1)
    reaper.SetTrackSelected(newTrack, true)
    _, newName = reaper.GetSetMediaTrackInfo_String(newTrack, 'P_NAME', 'Dummy', true)
end

hasDummy = false

totalTracks = reaper.GetNumTracks()
--Msg(totalTracks)
-- // iterate over tracks, check if items

for track = 0, totalTracks-1, 1 do
    t = reaper.GetTrack(0, track)
    --Msg('track')
    --Msg(track)
    _, trackname = reaper.GetSetMediaTrackInfo_String(t, 'P_NAME', '-', false)
    --Msg(trackname)
    if trackname == 'Dummy' then
        reaper.SetTrackSelected(t, true)
        hasDummy = true
        break
    end
end

if hasDummy then
    return
end

CreateDummy(totalTracks)