--[[
description: Auto Heads/Tails Trimming
author: R. Lee, W.N. Lowe, E. Shannon
version: 2.0
provides:
    [main] RL_SampleBufferReader.lua
    [main] RL_VariableTopTail.lua
    [main] RL_rtk_TopTailGui.lua
    [main] RL_SampleBufferReaderTest.lua
changelog:
    2.0
    # Initial reapack integration
]]

local headTailsCommand, regionAction
local supportActions = {
    ["Script: RL_SampleBufferReaderTest.lua"] = function(id) headTailsCommand = id end,
    ["Script: wnlowe_multiItemRegionResize.lua"] = function(id) regionAction = id end
}
local section = 0
local i = 0
repeat
    local r, name = reaper.kbd_enumerateActions(section, i)
    if r and r ~= 0 and supportActions[name] then supportActions[name](r) end
    i = i + 1
until (not r) or (r == 0) or (headTailsCommand and regionAction)


reaper.Undo_BeginBlock()

local numItems = reaper.CountSelectedMediaItems(0)
local allItems = {}
for i = 0, numItems do
    allItems[i] = reaper.GetSelectedMediaItem(0, i)
end

reaper.Main_OnCommand(40289, 0)

for j = 0, #allItems do
    reaper.SetMediaItemSelected( allItems[j], true )
    reaper.Main_OnCommand(headTailsCommand, 0)
    for k = 0,3,1 do
        reaper.Main_OnCommand(40225, 0)
        reaper.Main_OnCommand(40228, 0)
        reaper.Main_OnCommand(40228, 0)
        reaper.Main_OnCommand(regionAction,0)
    end
    reaper.SetMediaItemSelected( allItems[j], false )
end

for i = 0, #allItems do
    reaper.SetMediaItemSelected( allItems[i], true )
end

reaper.Undo_EndBlock("Mass Deployment of Heads and Tails script by WNL & RL", 0)
