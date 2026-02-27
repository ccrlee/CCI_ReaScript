-- @description Add Line to Clipboard
-- @about Adds the note of the selected item to the system clipboard
-- @author William N. Lowe
-- @version 1.00
-- @changelog
--   v 1.0
--   # Initial Script Release

local function main()
    local numItems = reaper.CountSelectedMediaItems()
    if numItems < 1 then
        reaper.ShowMessageBox("You do not have any items selected. Please select an item.", "Script Error", 0)
        return
    elseif numItems > 1 then
        local choice = reaper.ShowMessageBox("You have more than 1 item selected. Would you just like to use the first item in your selection?",
            "Script Error", 4)
        if choice ~= 6 then return end
    end

    local item = reaper.GetSelectedMediaItem(0, 0)
    local r, note = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
    if note ~= "" and note ~= nil then
        reaper.CF_SetClipboard(note)
        reaper.ShowMessageBox("ADDED \"" .. note .. "\" TO CLIPBOARD", "Script Complete", 0)
    else
        reaper.ShowMessageBox("No text found to add to clipboard", "Script Error", 0)
    end
end

main()
