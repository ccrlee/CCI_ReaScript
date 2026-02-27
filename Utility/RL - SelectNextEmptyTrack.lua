-- @noindex
-- @description Select Next Empty Track
-- @author Roc Lee
-- @version 0.1
function Msg (param)
    reaper.ShowConsoleMsg(tostring (param).."\n")
end

-- // get current selected track

totalTracks = reaper.GetNumTracks()
Msg(totalTracks)
-- // iterate over tracks, check if items

for track = 7, totalTracks, 1 do
    t = reaper.GetTrack(0, track)
    Msg('track')
    Msg(track)
    items = reaper.GetTrackNumMediaItems(t)
    Msg('items')
    Msg(items)
    if items < 1 then
        reaper.SetTrackSelected(t, true)
        break
    end
end
-- if no items set selected