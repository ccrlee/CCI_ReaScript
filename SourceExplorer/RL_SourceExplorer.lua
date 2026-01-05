--[[
description: Source Explorer - Audio clip library and browser
author: Roc Lee
provides:
    modules/AudioItem.lua
    modules/BatchExport.lua
    modules/BatchInsert.lua
    modules/BatchOperations.lua
    modules/BatchRename.lua
    modules/Collection.lua
    modules/CollectionManager.lua
    modules/CollectionPicker.lua
    modules/CollectionTree.lua
    modules/Colorutils.lua
    modules/config.lua
    modules/ContextMenu.lua
    modules/ItemTable.lua
    modules/PreviewPlayer.lua
    modules/RegionCreator.lua
    modules/Storage.lua
    modules/Theme.lua
    modules/UCSCategoryPicker.lua
    modules/UCSColumnSettings.lua
    modules/UCSDatabase.lua
    modules/UCSEditor.lua
    modules/UCSMetadata.lua
    modules/Utils.lua
    modules/WaveformViewer.lua
    modules/UCS_v8_2_1_Full_List.csv
version: 1.0
changelog:
    1.5
    # Basic UCS Features
    # Batch operations
    # Spectral WaveformViewer
    # Various UX improvements
    1.0
    # Complete modular rewrite
    # Improved waveform display with fades
    # Better preview system
    # Clean architecture
about:
    Source Explorer helps you manage and organize audio clips.
    Features:
    - Store clips from your project
    - Visual waveform display
    - Audio preview with click-to-play
    - Search and filter
    - Import/Export libraries
    - Save to project
--]]

local VSDEBUG = dofile("c:/Users/ccuts/.vscode/extensions/antoinebalaine.reascript-docs-0.1.16/debugger/LoadDebug.lua")
-- local VSDEBUG = dofile("c:/Users/rocle/.vscode/extensions/antoinebalaine.reascript-docs-0.1.16/debugger/LoadDebug.lua")
-- ============================================================================
-- MODULE SETUP
-- ============================================================================

-- Set up module search path
local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "modules/?.lua"

-- Load ultraschall API if available
local ultraschall_path = reaper.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua"
if reaper.file_exists(ultraschall_path) then
    dofile(ultraschall_path)
end

-- Load modules
local config = require("config")
local Utils = require("Utils")
local Storage = require("Storage")
local AudioItem = require("AudioItem")
local PreviewPlayer = require("PreviewPlayer")
local WaveformViewer = require("WaveformViewer")
local ItemTable = require("ItemTable")
local Collection = require("Collection")
local CollectionManager = require("CollectionManager")
local CollectionTree = require("CollectionTree")
local CollectionPicker = require("CollectionPicker")
local ContextMenu = require("ContextMenu")
local BatchOperations = require("BatchOperations")
local UCSMetadata = require("UCSMetadata")
local UCSDatabase = require("UCSDatabase")
local UCSEditor = require("UCSEditor")
local UCSCategoryPicker = require("UCSCategoryPicker")
local UCSColumnSettings = require("UCSColumnSettings")
local Theme = require("Theme")

-- Check for required extensions
if not Utils.CheckSWSInstalled() then
    return
end

-- ============================================================================
-- GLOBAL STATE
-- ============================================================================

-- ImGui context
local ctx = reaper.ImGui_CreateContext('Source Explorer', reaper.ImGui_ConfigFlags_None())

-- Load ImGui
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.2'

-- Data
local selectedItems = {} -- Stored/captured items
local projectItems = {}  -- Current project items

-- Options
local col_tree_options = {
    show_item_counts = true,
    show_all_items = true,

    on_collection_clicked = function(collection)
        -- Existing click handler
        current_collection = collection
    end,

    -- NEW: Handle drops
    on_items_dropped = function(collection, item_indices)
        -- Don't allow dropping on All Items or Favorites
        if collection.id == "all" or collection.id == "favorites" then
            Utils.Msg("Cannot add items to " .. collection.name, config.DEBUG)
            return
        end

        -- Add items to collection
        for _, index in ipairs(item_indices) do
            if selectedItems[index] then
                selectedItems[index]:addToCollection(collection.id)
            end
        end

        -- Save changes
        SaveData()

        -- Show feedback
        Utils.Msg("Added " .. #item_indices .. " item(s) to " .. collection.name, config.DEBUG)
    end,
}

local col_picker_options = {
    show_hierarchy = true,
    allow_new_collection = true,
    modal = true
}

-- Core components
local player = PreviewPlayer.new()
local waveform = WaveformViewer.new()
local collection_manager = CollectionManager.new()
local collection_tree = CollectionTree.new(collection_manager, col_tree_options)
local collection_picker = CollectionPicker.new(collection_manager, col_picker_options)
local batch_ops = BatchOperations.new()

-- Context menu
local item_context_menu = ContextMenu.new("item_context")

-- Init
collection_manager:setCurrentCollection(nil)

-- UI state
local search_text = ""
local split_ratio = config.TABLE_SPLIT_RATIO
local last_split_ratio = config.TABLE_SPLIT_RATIO
local show_export_popup = false
local FLT_MAX = 3.402823466e+38
local show_collections_sidebar = true
local collections_sidebar_width = 200
local show_projectSelection = true
local context_menu_target_item = nil
local show_batch_insert_dialog = false
local batch_insert_spacing = 0.0
local batch_insert_selected_items = {}
local ucs_clipboard = nil
local ucs_column_settings = UCSColumnSettings.new(config)

-- Initialize database
local ucs_database = UCSDatabase.new()
local csv_path = script_path .. "modules\\UCS_v8_2_1_Full_List.csv"
local success, msg = ucs_database:load(csv_path)
if success then
    Utils.Msg("✓ " .. msg .. "\n")
else
    Utils.Msg("✗ UCS Database load failed: " .. msg .. "\n")
end

-- Initialize UCS Editor
local ucs_editor = UCSEditor.new(ucs_database, {
    default_creator = config.UCS.DEFAULT_CREATOR_ID,
    default_source = config.UCS.DEFAULT_SOURCE_ID,
    max_fxname_length = config.UCS.MAX_FXNAME_LENGTH,
    max_keyword_suggestions = config.UCS.MAX_KEYWORD_SUGGESTIONS,
    start_expanded = config.UCS.EDITOR_EXPANDED,
})

-- Project tracking
local last_project_path = ""

-- When creating your stored items table
stored_table = ItemTable.new({
    id = "stored_items",
    columns = { "Index", "File", "Take Name" },
    show_checkbox = true,
    editable_takename = true,

    -- NEW: UCS Support
    ucs_mode = config.UCS.MODE_ENABLED,
    ucs_database = ucs_database,
    ucs_config = config.UCS,

    -- Callbacks
    on_click = function(row, item)
        -- Get click position to check if it's on status column
        local mouse_x = reaper.ImGui_GetMousePos(ctx)
        -- If clicked on status column (first few pixels)
        -- Open/expand UCS Editor
        if ucs_editor then
            ucs_editor:setExpanded(true)

            -- Focus appropriate field based on status
            local status = item:getUCSStatus()
            if status == "not_set" then
                -- Auto-focus category picker
            elseif status == "incomplete" then
                -- Auto-focus first empty field
            end
        end

        -- Update UCS Editor with selected items
        local filtered_items = collection_manager:filterItemsByCollection(selectedItems)
        local selected_items = {}
        for _, idx in ipairs(stored_table:getSelectedIndices()) do
            if filtered_items[idx] then
                table.insert(selected_items, filtered_items[idx])
            end
        end
        ucs_editor:setItems(selected_items)
    end,

    on_ucs_change = function(row, item)
        -- UCS data changed inline, save to storage
        SaveData()
    end,

    -- Add to ItemTable initialization
    on_right_click = function(row, item)
        ShowItemContextMenu(row, item)
    end,

    on_double_click = function(row, item)
        InsertItem(item)
    end,

    on_favorite_toggle = function(row, is_favorite)
        selectedItems[row]:toggleFavorite()
    end
})

local project_table = ItemTable.new({
    id = "project_items",
    columns = { "Index", "File", "Take Name" },
    editable_takename = true,

    on_takename_edit = function(row, new_name)
        -- Update the AudioItem object
        projectItems[row].takeName = new_name
        local item = reaper.GetMediaItem(0, projectItems[row].index)
        -- Update the actual Reaper item's take name
        if item then
            reaper.GetSetMediaItemTakeInfo_String(reaper.GetMediaItemTake(item, 0), 'P_NAME', new_name, true)
            reaper.UpdateArrange()
        end
    end,

    on_click = function(row)
        local item = reaper.GetMediaItem(0, projectItems[row].index)
        -- Ctrl+Click to zoom to item
        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
            local startTime = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
            local length = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
            reaper.GetSet_LoopTimeRange(true, true, startTime, startTime + length, true)
            Utils.ReaperNamedCommand(40031) -- View: Zoom time selection
        end
    end
})

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Check if project changed and reload data
function CheckProjectChange()
    local current_project = reaper.GetProjectPath()

    if current_project ~= last_project_path then
        last_project_path = current_project

        -- Reload data from new project
        local loadData = Storage.LoadTableFromProject(config.SCRIPT_NAME, config.SAVED_INFO_KEY)
        if loadData then
            -- Convert plain tables back to AudioItem objects
            selectedItems = {}
            for i, tbl in ipairs(loadData) do
                selectedItems[i] = AudioItem.fromTable(tbl)
            end
            Utils.Msg("Loaded " .. #selectedItems .. " items from project")

            -- Sync favorites collection with favorite flags
            for _, item in ipairs(selectedItems) do
                if item.favorite then
                    -- Ensure favorited items are in Favorites collection
                    if not item:isInCollection("FAVORITES") then
                        item:addToCollection("FAVORITES")
                    end
                else
                    -- Ensure non-favorited items are NOT in Favorites collection
                    if item:isInCollection("FAVORITES") then
                        item:removeFromCollection("FAVORITES")
                    end
                end
            end
        else
            selectedItems = {}
            Utils.Msg("No saved data in this project")
        end

        local collections_data = Storage.LoadTableFromProject(config.SCRIPT_NAME, config.SAVED_INFO_KEY .. "_collections")
        if collections_data then
            collection_manager:fromTable(collections_data)
            Utils.Msg("Loaded collections", config.DEBUG)
        else
            -- collection_manager = CollectionManager.new() -- need this?
        end

        -- Reset UI state
        stored_table:clearSelection()
        project_table:clearSelection()
        search_text = ""
        waveform:clearCache()
    end
end

-- Get all items from current REAPER selection
function GetProjectItems()
    projectItems = AudioItem.fromReaperSelection()
end

-- Insert an AudioItem at edit cursor
function InsertItem(audio_item)
    if not audio_item or not audio_item:isValid() then
        Utils.Msg("Invalid item")
        return nil
    end

    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("Please select a track first!", "No Track Selected", 0)
        return nil
    end

    reaper.PreventUIRefresh(1)

    local newItem = reaper.AddMediaItemToTrack(track)
    reaper.SetItemStateChunk(newItem, audio_item.chunk, true)
    reaper.SetMediaItemPosition(newItem, reaper.GetCursorPosition(), false)

    -- Restore take name
    if audio_item.takeName and audio_item.takeName ~= "" then
        local take = reaper.GetMediaItemTake(newItem, 0)
        if take then
            reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', audio_item.takeName, true)
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()

    Utils.Msg("Inserted: " .. audio_item:getDisplayName())

    return newItem
end

-- Capture selected items from project
function CaptureSelection(shouldDelete)
    local items = AudioItem.fromReaperSelection()

    if #items == 0 then
        reaper.ShowMessageBox("No items selected!", "Nothing to Capture", 0)
        return
    end

    -- Add to stored items
    for _, item in ipairs(items) do
        table.insert(selectedItems, item)
    end

    -- Delete from project if requested
    if shouldDelete then
        reaper.PreventUIRefresh(1)

        Utils.ReaperNamedCommand(40006) -- delete selected

        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()
    end

    -- Save to project
    SaveData()

    Utils.Msg("Captured " .. #items .. " items")
end

-- Save data to project
function SaveData()
    -- Convert AudioItems to plain tables for serialization
    local tables = {}
    for i, item in ipairs(selectedItems) do
        tables[i] = item:toTable()
    end

    Storage.SaveTableToProject(config.SCRIPT_NAME, config.SAVED_INFO_KEY, tables)

    local collections_data = collection_manager:toTable()
    Storage.SaveTableToProject(config.SCRIPT_NAME, config.SAVED_INFO_KEY .. "_collections", collections_data)
end

-- Export data to file
function ExportData()
    if #selectedItems == 0 then
        reaper.ShowMessageBox("No items to export!", "Nothing to Export", 0)
        return
    end

    -- Convert to tables
    local tables = {}
    for i, item in ipairs(selectedItems) do
        tables[i] = item:toTable()
    end

    local success, msg = Storage.ExportToProjectDirectory(tables, 'CapturedSource.lua')

    if success then
        show_export_popup = true
        reaper.ImGui_OpenPopup(ctx, 'Export Success')
    else
        reaper.ShowMessageBox(msg or "Export failed!", "Export Error", 0)
    end
end

-- Import data from file
function ImportData()
    local success, msg = Storage.ImportDataWithDialog(selectedItems, AudioItem.fromTable)

    if success then
        SaveData()
        Utils.Msg(msg, true)
    else
        if msg then
            Utils.Msg("Import failed: " .. msg)
        end
    end
end

-- Reveal file in OS file explorer
function RevealInExplorer(filepath)
    if not filepath or filepath == "" then
        return
    end

    reaper.CF_LocateInExplorer(filepath)
end

-- Build and show context menu for an item
function ShowItemContextMenu(row, item)
    context_menu_target_item = item

    -- Clear previous menu
    item_context_menu:clear()

    -- Insert action
    item_context_menu:addItem("Insert at Cursor", function()
        InsertItem(item)
    end, "⏎")

    item_context_menu:addSeparator()

    item_context_menu:addItem("Collection Picker", function()
        if not stored_table:isRowSelected(row) then
            stored_table:clearMultiSelection()
            stored_table:addToSelection(row)
        end

        -- Get all selected items
        local selected_indices = stored_table:getSelectedIndices()
        local selected_items = {}
        local filtered_items = collection_manager:filterItemsByCollection(selectedItems)

        for _, idx in ipairs(selected_indices) do
            if filtered_items[idx] then
                table.insert(selected_items, filtered_items[idx])
            end
        end

        -- Open picker with selected items
        if #selected_items == 1 then
            collection_picker:open(selected_items[1])
        elseif #selected_items > 1 then
            collection_picker:openBulk(selected_items)
        end
    end, "⏎")

    item_context_menu:addSeparator()

    -- Add to Collection submenu
    local collection_items = {}
    if collection_manager and collection_manager.collections then
        for _, col in ipairs(collection_manager.collections) do
            if col.name ~= "All Items" then
                local is_in_collection = item:isInCollection(col.id)
                local check_mark = is_in_collection and " ✓" or ""

                table.insert(collection_items, {
                    label = col:getDisplayName() .. check_mark,
                    callback = function()
                        -- Re-check at CLICK time!
                        if item:isInCollection(col.id) then
                            item:removeFromCollection(col.id)
                        else
                            item:addToCollection(col.id)
                        end

                        SaveData()
                    end
                })
            end
        end
    end

    if #collection_items > 0 then
        item_context_menu:addSubmenu("Add to Collection", collection_items, "📁")
    else
        item_context_menu:addItem("Add to Collection", nil, "📁", false) -- Disabled if no collections
    end

    -- Favorite toggle
    local fav_label = item.favorite and "Remove from Favorites" or "Add to Favorites"
    item_context_menu:addItem(fav_label, function()
        item:toggleFavorite()
        SaveData()
    end, "⭐")

    item_context_menu:addSeparator()

    -- File operations
    item_context_menu:addItem("Reveal in Explorer", function()
        RevealInExplorer(item.file)
    end, "📁")

    item_context_menu:addItem("Copy File Path", function()
        reaper.CF_SetClipboard(item.file)
        Utils.Msg("Copied: " .. item.file)
    end, "📋")

    item_context_menu:addSeparator()

    -- Delete
    item_context_menu:addItem("Delete", function()
        -- Find and remove item
        for i, itm in ipairs(selectedItems) do
            if itm == item then
                table.remove(selectedItems, i)
                stored_table:clearSelection()
                SaveData()
                Utils.Msg("Deleted: " .. item:getDisplayName())
                break
            end
        end
    end, "🗑️")

    item_context_menu:addSeparator()

    if item:hasUCS() then
        item_context_menu:addItem("Copy UCS Filename", function()
            local filename = item:getUCSFilename()
            if filename then
                reaper.CF_SetClipboard(filename .. ".wav")
            end
        end, "📋")

        item_context_menu:addItem("Copy UCS Data", function()
            -- Store UCS data in global clipboard variable
            ucs_clipboard = item.ucs:clone()
            reaper.ShowConsoleMsg("UCS data copied\n")
        end, "📋")
    end

    if ucs_clipboard then
        item_context_menu:addItem("Paste UCS Data", function()
            -- Show confirmation dialog
            -- show_paste_confirm = true
            local selected_indices = stored_table:getSelectedIndices()
            local selected_items = {}
            local filtered_items = collection_manager:filterItemsByCollection(selectedItems)
            for _, idx in ipairs(selected_indices) do
                if filtered_items[idx] then
                    filtered_items[idx].ucs = ucs_clipboard
                end
            end
        end, "📋")
    end

    -- Open the menu
    item_context_menu:open(ctx)
end

-- ============================================================================
-- UI DRAWING FUNCTIONS
-- ============================================================================

-- Draw toolbar with buttons and search
function DrawToolbar()
    reaper.ImGui_BeginGroup(ctx)

    -- In your toolbar drawing code
    if reaper.ImGui_Button(ctx, "🏷️ UCS Mode", 100, 0) then
        stored_table:toggleUCSMode()
        config.UCS.MODE_ENABLED = stored_table:isUCSMode()
        -- SaveConfig()
    end

    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Toggle UCS metadata columns (Ctrl+U)")
    end

    reaper.ImGui_SameLine(ctx)

    if stored_table:isUCSMode() then
        if reaper.ImGui_Button(ctx, "⚙️ Columns...", 100, 0) then
            ucs_column_settings:open()
        end
    end

    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Configure UCS column visibility")
    end

    reaper.ImGui_SameLine(ctx)

    -- Insert button
    if reaper.ImGui_Button(ctx, 'Insert') then
        local selected_idx = stored_table:getSelected()

        if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
            local selected_indices = stored_table:getSelectedIndices()
            local selected_items = {}
            local filtered_items = collection_manager:filterItemsByCollection(selectedItems)
            
            for _, idx in ipairs(selected_indices) do
                if filtered_items[idx] then
                    table.insert(selected_items, filtered_items[idx])
                end
            end

            if #selected_items > 0 then
                batch_ops:openExport(selected_items)
            end
        elseif selected_idx > 0 and selectedItems[selected_idx] then
            InsertItem(selectedItems[selected_idx])
        end

        -- Also insert from project table if selected ::: BUG WILL INSERT FROM BOTH
        -- local project_selected = project_table:getSelected()
        -- if project_selected > 0 and projectItems[project_selected] then
        --     InsertItem(projectItems[project_selected])
        -- end
    end

    reaper.ImGui_SameLine(ctx)

    -- Capture button
    if reaper.ImGui_Button(ctx, 'Capture Selection') then
        local ctrl = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
        CaptureSelection(ctrl)
    end

    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Capture selected items\nCtrl+Click to delete from project")
    end

    reaper.ImGui_SameLine(ctx)

    -- Import button
    if reaper.ImGui_Button(ctx, 'Import') then
        ImportData()
    end

    reaper.ImGui_SameLine(ctx)

    -- Clear button
    if reaper.ImGui_Button(ctx, 'Clear') then
        local retval = reaper.ShowMessageBox("Are you sure you want to clear?", "Clear all stored items", 1)

        if retval == 1 then
            selectedItems = {}
            stored_table:clearSelection()
            SaveData()
        end
    end

    reaper.ImGui_SameLine(ctx)

    -- Search box
    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, avail_w - 130)
    local changed, new_text = reaper.ImGui_InputText(ctx, '##search', search_text)
    if changed then
        search_text = new_text
        stored_table:setSearchFilter(search_text)
    end

    reaper.ImGui_SameLine(ctx)

    -- Clear search button
    if reaper.ImGui_Button(ctx, "X##clear") then
        search_text = ""
        stored_table:setSearchFilter("")
    end

    -- Right-aligned buttons
    local contentRegionWidth = reaper.ImGui_GetWindowWidth(ctx)

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetCursorPosX(ctx, contentRegionWidth - 105)

    -- Export button
    if reaper.ImGui_Button(ctx, 'Export') then
        ExportData()
    end

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetCursorPosX(ctx, contentRegionWidth - 60)

    -- Save button
    if reaper.ImGui_Button(ctx, 'Save') then
        SaveData()
        Utils.Msg("Saved " .. #selectedItems .. " items to project")
    end

    -- PHASE 4: Keyboard shortcuts help
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_SmallButton(ctx, "?") then
        local help_text = [[
    KEYBOARD SHORTCUTS:

    Collections:
    Ctrl+N       New collection
    Ctrl+E       Add item to collections
    Ctrl+A       Show all items
    Ctrl+Shift+S Toggle sidebar

    Selected Collection:
    F2           Rename
    Delete       Delete

    Items:
    Right-click  Add to collections
    Alt+Click    Delete item
    Double-click Insert to project
    ]]
        reaper.ShowMessageBox(help_text, "Keyboard Shortcuts", 0)
    end

    -- Add tooltip
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Show keyboard shortcuts")
    end

    reaper.ImGui_EndGroup(ctx)

    -- Export success popup
    if reaper.ImGui_BeginPopupModal(ctx, 'Export Success', true, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_Text(ctx, 'File exported to project directory')
        reaper.ImGui_Text(ctx, 'Filename: CapturedSource.lua')
        reaper.ImGui_Separator(ctx)

        if reaper.ImGui_Button(ctx, 'OK', 120, 0) then
            reaper.ImGui_CloseCurrentPopup(ctx)
            show_export_popup = false
        end

        reaper.ImGui_EndPopup(ctx)
    end
end

-- Draw item count info
function DrawItemCount()
    local filtered_count = stored_table:getFilteredCount(selectedItems)
    -- local selected_count = stored_table:getSelectedCount()

    local text = string.format("Stored: %d", #selectedItems)

    -- if selected_count > 0 then  -- ← NEW
    --     text = text .. string.format(" (%d selected)", selected_count)
    -- end

    if search_text ~= "" then
        text = text .. string.format(" (showing %d)", filtered_count)
    end

    reaper.ImGui_Text(ctx, text)
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, " | ")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, string.format("Project: %d items", #projectItems))
end

-- Draw batch operations toolbar (shown when items are selected)
function DrawBatchToolbar()
    local selected_count = stored_table:getSelectedCount()

    -- Early exit if nothing selected
    if selected_count == 0 then
        return
    end

    -- Get selected items from filtered list
    local selected_indices = stored_table:getSelectedIndices()
    local filtered_items = collection_manager:filterItemsByCollection(selectedItems)
    local selected_items = {}

    for _, idx in ipairs(selected_indices) do
        if filtered_items[idx] then
            table.insert(selected_items, filtered_items[idx])
        end
    end

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, " | ")
    reaper.ImGui_SameLine(ctx)

    -- BUTTON 1: Selection Badge (colored, non-clickable)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xFF4444AA)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF5555BB)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xFF6666CC)
    reaper.ImGui_Button(ctx, string.format("  %d selected  ", selected_count), 0, 0)
    reaper.ImGui_PopStyleColor(ctx, 3)

    reaper.ImGui_SameLine(ctx)

    -- BUTTON 2: Insert All
    -- Insert All button (opens dialog)
    if reaper.ImGui_Button(ctx, "⏎ Insert All...") then
        batch_insert_selected_items = selected_items
        show_batch_insert_dialog = true
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Insert all selected items with spacing options")
    end

    reaper.ImGui_SameLine(ctx)

    -- Replace inline rename button with:
    if reaper.ImGui_Button(ctx, "✏️ Rename") then
        batch_ops:openRename(selected_items)
    end

    reaper.ImGui_SameLine(ctx)

    -- BUTTON 3: Add to Collection
    if reaper.ImGui_Button(ctx, "📁 Add to Collection") then
        collection_picker:openBulk(selected_items)
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Add all selected items to a collection")
    end

    reaper.ImGui_SameLine(ctx)

    -- BUTTON 4: Toggle Favorite
    if reaper.ImGui_Button(ctx, "⭐ Toggle Favorite") then
        for _, item in ipairs(selected_items) do
            item:toggleFavorite()

            -- Auto-sync with Favorites collection
            if item.favorite then
                item:addToCollection("FAVORITES")
            else
                item:removeFromCollection("FAVORITES")
            end
        end
        SaveData()
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Toggle favorite status for all selected items")
    end

    reaper.ImGui_SameLine(ctx)

    -- Export Selected button
    if reaper.ImGui_Button(ctx, "💾 Export") then
        ExportSelectedItems(selected_items)
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Export selected items to file")
    end

    reaper.ImGui_SameLine(ctx)

    -- BUTTON 5: Delete Selected
    if reaper.ImGui_Button(ctx, "🗑️ Delete") then
        local result = reaper.ShowMessageBox(
            string.format("Delete %d item(s)?\n\nThis action cannot be undone.", selected_count),
            "Delete Items",
            4 -- Yes/No
        )

        if result == 6 then -- Yes
            -- Remove items from main array
            for _, item_to_delete in ipairs(selected_items) do
                for i = #selectedItems, 1, -1 do
                    if selectedItems[i] == item_to_delete then
                        table.remove(selectedItems, i)
                    end
                end
            end

            stored_table:clearMultiSelection()
            SaveData()
        end
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Delete all selected items")
    end

    reaper.ImGui_SameLine(ctx)

    -- BUTTON 6: Deselect All
    if reaper.ImGui_Button(ctx, "✕ Deselect") then
        stored_table:clearMultiSelection()
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Clear selection")
    end
end

-- Batch Insert Dialog
function DrawBatchInsertDialog()
    if not show_batch_insert_dialog then
        return
    end

    -- Open the modal popup
    if not reaper.ImGui_IsPopupOpen(ctx, 'Batch Insert Options') then
        reaper.ImGui_OpenPopup(ctx, 'Batch Insert Options')
    end

    reaper.ImGui_SetNextWindowSize(ctx, 400, 300, reaper.ImGui_Cond_FirstUseEver())

    local visible, open = reaper.ImGui_BeginPopupModal(ctx, 'Batch Insert Options', true,
        reaper.ImGui_WindowFlags_AlwaysAutoResize())

    if not visible then
        return
    end

    if not open then
        show_batch_insert_dialog = false
        reaper.ImGui_EndPopup(ctx)
        return
    end

    local item_count = #batch_insert_selected_items

    reaper.ImGui_Text(ctx, string.format("Insert %d items at cursor position", item_count))
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    -- Spacing input
    reaper.ImGui_Text(ctx, "Spacing between items (seconds):")
    reaper.ImGui_SetNextItemWidth(ctx, 200)
    local changed, new_spacing = reaper.ImGui_InputDouble(ctx, "##spacing", batch_insert_spacing, 0.1, 1.0, "%.2f")
    if changed then
        batch_insert_spacing = math.max(0, new_spacing) -- Don't allow negative
    end

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Text(ctx, "Examples:")
    reaper.ImGui_BulletText(ctx, "0.0 = Items overlapped at same position")
    reaper.ImGui_BulletText(ctx, "0.5 = Half second gap between items")
    reaper.ImGui_BulletText(ctx, "1.0 = One second gap between items")

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)

    -- Buttons
    if reaper.ImGui_Button(ctx, 'Insert', 120, 0) then
        BatchInsertItems(batch_insert_selected_items, batch_insert_spacing)
        stored_table:clearMultiSelection()
        show_batch_insert_dialog = false
        reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_SameLine(ctx)

    if reaper.ImGui_Button(ctx, 'Cancel', 120, 0) then
        show_batch_insert_dialog = false
        reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_EndPopup(ctx)
end

-- Batch insert items with spacing
function BatchInsertItems(items, spacing)
    local track = reaper.GetSelectedTrack(0, 0)
    if not track then
        reaper.ShowMessageBox("Please select a track first!", "No Track Selected", 0)
        return
    end

    local start_pos = reaper.GetCursorPosition()
    local current_pos = start_pos

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    for i, item in ipairs(items) do
        local newItem = reaper.AddMediaItemToTrack(track)
        reaper.SetItemStateChunk(newItem, item.chunk, true)
        reaper.SetMediaItemPosition(newItem, current_pos, false)

        -- Restore take name
        if item.takeName and item.takeName ~= "" then
            local take = reaper.GetMediaItemTake(newItem, 0)
            if take then
                reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', item.takeName, true)
            end
        end

        -- Calculate next position
        local item_length = reaper.GetMediaItemInfo_Value(newItem, 'D_LENGTH')
        current_pos = current_pos + item_length + spacing
    end

    reaper.Undo_EndBlock("Insert " .. #items .. " items with spacing", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()

    Utils.Msg("Inserted " .. #items .. " items")
end

-- Export selected items to file
function ExportSelectedItems(items)
    local export_data = {}
    for i, item in ipairs(items) do
        export_data[i] = item:toTable()
    end

    local filename = string.format("SelectedItems_%s.lua", os.date("%Y%m%d_%H%M%S"))
    local success, msg = Storage.ExportToProjectDirectory(export_data, filename)

    if success then
        reaper.ShowMessageBox(
            string.format("Exported %d items to:\n%s", #items, filename),
            "Export Success",
            0
        )
    else
        reaper.ShowMessageBox(msg or "Export failed", "Error", 0)
    end
end

-- Draw the split tables section
-- Draw the split tables section with collections sidebar
-- PHASE 3: Updated to include collection tree and filtering
function DrawTables()
    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local waveform_height = config.WAVEFORM_HEIGHT

    -- PHASE 4: Toggle sidebar with Ctrl+Shift+S
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_S()) and
        reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and
        reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then
        show_collections_sidebar = not show_collections_sidebar
    end

    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow()) and
        reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and
        reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift()) then
        show_projectSelection = not show_projectSelection

        if show_projectSelection then
            split_ratio = last_split_ratio
        else
            split_ratio = 0.99
        end
    end

    -- PHASE 4: Ctrl+A to show all items (clear filter)
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_A()) and
        reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
        collection_manager:setCurrentCollection(nil)
    end

    -- In your keyboard input handling section
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_U()) and
        reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
        stored_table:toggleUCSMode()
        config.UCS.MODE_ENABLED = stored_table:isUCSMode()
        -- SaveConfig()
    end

    -- Calculate heights
    local ucs_editor_height = 0
    if stored_table:isUCSMode() and ucs_editor:isExpanded() then
        ucs_editor_height = avail_h * 0.3 < 400 and 400 or avail_h * 0.3 -- Height for expanded UCS Editor
        waveform_height = config.WAVEFORM_HEIGHT * config.WAVEFORM_UCS_SCALE
    elseif stored_table:isUCSMode() then
        ucs_editor_height = 35 -- Height for collapsed UCS Editor header
    end

    local tables_height = avail_h - waveform_height - ucs_editor_height - 10
    local table1_height = tables_height * split_ratio
    if not show_projectSelection then table1_height = tables_height end
    local table2_height = tables_height * (1 - split_ratio)

    -- PHASE 4: Resizable sidebar
    local collections_width = show_collections_sidebar and collections_sidebar_width or 0
    local tables_width = avail_w - collections_width - (show_collections_sidebar and 5 or 0)

    -- Draw sidebar with resize handle
    if show_collections_sidebar then
        -- Set minimum and maximum widths
        local min_width = 150
        local max_width = avail_w * 0.5 -- Max 50% of window

        -- Keep width in bounds
        collections_sidebar_width = math.max(min_width, math.min(max_width, collections_sidebar_width))

        collections_width = collections_sidebar_width
        tables_width = avail_w - collections_width - 5
    end

    -- PHASE 4: Draw collections sidebar with resize handle
    if show_collections_sidebar then
        local clicked_col, tree_changed = collection_tree:draw(ctx, collections_width, tables_height, selectedItems)

        -- Save if collections were modified
        if tree_changed then
            SaveData()
        end

        -- Resize handle
        reaper.ImGui_SameLine(ctx, 0, 0)

        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x00000000) -- Transparent
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x40FFFFFF)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x80FFFFFF)

        reaper.ImGui_Button(ctx, "##sidebar_resize", 5, tables_height)

        if reaper.ImGui_IsItemActive(ctx) then
            local mouse_delta_x, _ = reaper.ImGui_GetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
            if mouse_delta_x ~= 0 then
                collections_sidebar_width = collections_sidebar_width + mouse_delta_x
                reaper.ImGui_ResetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
            end
        end

        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeEW())
        end

        reaper.ImGui_PopStyleColor(ctx, 3)

        reaper.ImGui_SameLine(ctx, 0, 0)
    end

    -- Begin tables column
    reaper.ImGui_BeginGroup(ctx)

    -- PHASE 3: Get filtered items based on current collection
    local filtered_items = collection_manager:filterItemsByCollection(selectedItems)

    -- Draw stored items table
    local clicked, double_clicked, delete, right_clicked = stored_table:draw(ctx, filtered_items, tables_width,
        table1_height)

    if clicked then
        stored_table:setSelected(clicked)
    end

    if delete then
        -- PHASE 3: Find actual index in main array (not filtered)
        local actual_idx = -1
        for i, item in ipairs(selectedItems) do
            if item == filtered_items[delete] then
                actual_idx = i
                break
            end
        end

        if actual_idx > 0 then
            table.remove(selectedItems, actual_idx)
            stored_table:clearSelection()
            SaveData()
        end
    end

    if show_projectSelection then
        -- Draggable splitter
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0xFF444444)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0xFF666666)
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0xFF888888)

        reaper.ImGui_Button(ctx, '##splitter', -1, 5)

        if reaper.ImGui_IsItemActive(ctx) then
            local _, mouse_delta_y = reaper.ImGui_GetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
            if mouse_delta_y ~= 0 then
                split_ratio = split_ratio + (mouse_delta_y / tables_height)
                split_ratio = math.max(0.2, math.min(0.8, split_ratio))
                reaper.ImGui_ResetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
            end
        end

        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNS())
        end

        reaper.ImGui_PopStyleColor(ctx, 3)

        -- Draw project items table
        project_table:drawSimple(ctx, projectItems, tables_width, table2_height - 5)

        last_split_ratio = split_ratio
    end

    reaper.ImGui_EndGroup(ctx)
end

-- Draw waveform section
function DrawWaveform()
    local selected_item = stored_table:getSelectedItem()
    local waveform_height = config.WAVEFORM_HEIGHT

    if stored_table:isUCSMode() and ucs_editor:isExpanded() then
        waveform_height = waveform_height * config.WAVEFORM_UCS_SCALE
    end

    if selected_item then
        waveform:draw(ctx, selected_item, player, waveform_height)
    else
        -- Show empty waveform area
        local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
        if reaper.ImGui_BeginChild(ctx, 'WaveformEmpty', avail_w, config.WAVEFORM_HEIGHT, reaper.ImGui_ChildFlags_Border()) then
            reaper.ImGui_TextColored(ctx, config.COLORS.TEXT_DISABLED, "No item selected")
            reaper.ImGui_EndChild(ctx)
        end
    end
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

function main()
    -- Theme.Push(ctx)
    -- Check for project changes
    CheckProjectChange()

    -- Update project items list
    GetProjectItems()

    -- Set window size
    reaper.ImGui_SetNextWindowSize(ctx, config.DEFAULT_WINDOW_WIDTH, config.DEFAULT_WINDOW_HEIGHT,
        reaper.ImGui_Cond_FirstUseEver())

    reaper.ImGui_SetNextWindowSizeConstraints(ctx, 600, 400, FLT_MAX, FLT_MAX)

    local visible, open = reaper.ImGui_Begin(ctx, 'Source Explorer', true, reaper.ImGui_WindowFlags_None())

    if visible then
        -- Draw UI sections
        DrawToolbar()

        reaper.ImGui_Separator(ctx)

        DrawItemCount()

        DrawBatchToolbar()

        reaper.ImGui_Separator(ctx)

        DrawTables()

        reaper.ImGui_Separator(ctx)

        DrawWaveform()

        -- Draw UCS Editor (if UCS mode is enabled)
        if stored_table:isUCSMode() then
            reaper.ImGui_Separator(ctx)

            -- Get available space
            local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)

            -- Draw UCS Editor
            local applied = ucs_editor:draw(ctx, avail_w, avail_h)

            if applied then
                -- UCS changes were applied, save data
                SaveData()
            end
        end

        -- In main() function, after batch operations
        local columns_changed = ucs_column_settings:draw(ctx)

        if columns_changed then
            -- Settings were applied, save config
            -- SaveConfig()

            -- Optional: Show confirmation message
            -- Utils.Msg("Column settings saved\n")
        end

        -- NEW: Draw context menu (ADD THIS LINE)
        item_context_menu:draw(ctx)

        -- Draw batch insert dialog
        DrawBatchInsertDialog()

        -- After DrawBatchInsertDialog()
        batch_ops:draw(ctx)

        -- Handle rename completion
        if batch_ops.rename:wasRenamed() then
            SaveData()
        end

        reaper.ImGui_End(ctx)
    end



    local picker_changed, should_clear_selection = collection_picker:draw(ctx)

    if picker_changed then
        SaveData()
    end

    if should_clear_selection then
        stored_table:clearMultiSelection()
    end

    -- Theme.Pop(ctx)

    if open then
        -- Update player (auto-stop when finished)
        player:update()

        reaper.defer(main)
    else
        Cleanup()
    end
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

function Cleanup()
    player:stop()
    waveform:clearCache()
    Utils.Msg("Source Explorer closed")
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Load saved data
local loadData = Storage.LoadTableFromProject(config.SCRIPT_NAME, config.SAVED_INFO_KEY)
if loadData then
    for i, tbl in ipairs(loadData) do
        selectedItems[i] = AudioItem.fromTable(tbl)
    end
    Utils.Msg("Loaded " .. #selectedItems .. " items")
end

-- Start main loop
reaper.defer(main)
