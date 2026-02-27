-- @noindex
-- @description Set Selection to Items and INsert Empty Item
-- @author Roc Lee
-- @version 0.1
function Msg (param)
    reaper.ShowConsoleMsg(tostring (param).."\n")
end


--reaper.Main_OnCommand(40290, 0)

reaper.AddMediaItemToTrack(reaper.GetLastTouchedTrack())