-- @description Deselect First Item
-- @author Roc Lee
-- @version 1.0


numSelectedItems = reaper.CountSelectedMediaItems(0)

firstItem = reaper.GetSelectedMediaItem(0, 0)

reaper.SetMediaItemSelected(firstItem, false)