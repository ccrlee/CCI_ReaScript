-- @noindex
Pos = reaper.GetCursorPosition()
Item = reaper.GetSelectedMediaItem(0, 0)
ItemPos = reaper.GetMediaItemInfo_Value(Item, "D_POSITION")
Offset = Pos - ItemPos
reaper.SetMediaItemInfo_Value(Item, "D_SNAPOFFSET", Offset)
