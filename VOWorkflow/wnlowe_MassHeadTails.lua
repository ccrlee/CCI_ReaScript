-- @noindex
------U S E R  S P E C I F I C ---------
headTailsCommand = "_RS68316f464d073fb59581e7077b9d08f750b2cab9"
--######################################

reaper.Undo_BeginBlock()

numItems = reaper.CountSelectedMediaItems(0)
allItems = {}
for i = 0, numItems do
    allItems[i] = reaper.GetSelectedMediaItem(0, i)
end

reaper.Main_OnCommand(40289, 0)

for j = 0, #allItems do
    reaper.SetMediaItemSelected( allItems[j], true )
    commandId = reaper.NamedCommandLookup(headTailsCommand)
    reaper.Main_OnCommand(commandId, 0)
    reaper.SetMediaItemSelected( allItems[j], false )
end

for i = 0, #allItems do
    reaper.SetMediaItemSelected( allItems[i], true )
end

reaper.Undo_EndBlock("Mass Deployment of Heads and Tails script by WNL & RL", 0)
