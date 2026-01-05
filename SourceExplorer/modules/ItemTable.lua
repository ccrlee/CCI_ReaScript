-- ItemTable.lua
-- Reusable table component for displaying items in Source Explorer

local ItemTable = {}
ItemTable.__index = ItemTable

-- Load dependencies
local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"
local Utils = require("Utils")
local UCSCategoryPicker = require("UCSCategoryPicker")

-- Constructor
function ItemTable.new(options)
    options = options or {}

    local self = setmetatable({}, ItemTable)

    self.id = options.id or "table"
    self.columns = options.columns or { "Index", "File", "Take Name" }
    self.column_flags = options.column_flags or {}
    self.current_selected = -1
    self.search_filter = ""
    self.show_checkbox = options.show_checkbox or false
    self.editable_takename = options.editable_takename or false
    self.selected_indices = {}
    self.last_clicked_index = -1
    self.selected_item = nil

    -- UCS Support
    self.ucs_mode = options.ucs_mode or false
    self.ucs_database = options.ucs_database
    self.ucs_config = options.ucs_config or {}
    self.ucs_column_widths = options.ucs_column_widths or {}

    -- UCS Category pickers (one per row for inline editing)
    self.ucs_category_pickers = {}

    -- Callbacks
    self.on_click = options.on_click
    self.on_double_click = options.on_double_click
    self.on_takename_edit = options.on_takename_edit
    self.on_favorite_toggle = options.on_favorite_toggle
    self.on_right_click = options.on_right_click -- NEW: Add this line
    self.on_ucs_change = options.on_ucs_change   -- NEW: UCS data changed

    return self
end

-- Set search filter
function ItemTable:setSearchFilter(filter)
    self.search_filter = filter or ""
end

-- Get current selected index
function ItemTable:getSelected()
    return self.current_selected
end

function ItemTable:getSelectedItem()
    return self.selected_item
end

-- Set current selected index
function ItemTable:setSelected(index)
    self.current_selected = index
end

-- Clear selection
function ItemTable:clearSelection()
    self.current_selected = -1
end

-- Check if item should be shown based on search filter
function ItemTable:shouldShowItem(item)
    if self.search_filter == "" then
        return true
    end

    local search_lower = self.search_filter:lower()

    -- Search in filename
    local filename = Utils.GetFileNameFromPath(item.file):lower()
    if filename:find(search_lower, 1, true) then
        return true
    end

    -- Search in takename
    if item.takeName then
        local takename = item.takeName:lower()
        if takename:find(search_lower, 1, true) then
            return true
        end
    end

    -- Search in UCS metadata fields (if UCS mode enabled and item has UCS data)
    if self.ucs_mode and item.ucs then
        -- Search in category
        if item.ucs.category and item.ucs.category:lower():find(search_lower, 1, true) then
            return true
        end

        -- Search in subcategory
        if item.ucs.subcategory and item.ucs.subcategory:lower():find(search_lower, 1, true) then
            return true
        end

        -- Search in FX Name
        if item.ucs.fxname and item.ucs.fxname:lower():find(search_lower, 1, true) then
            return true
        end

        -- Search in keywords
        if item.ucs.keywords then
            for _, keyword in ipairs(item.ucs.keywords) do
                if keyword:lower():find(search_lower, 1, true) then
                    return true
                end
            end
        end

        -- Search in description
        if item.ucs.description and item.ucs.description:lower():find(search_lower, 1, true) then
            return true
        end
    end

    return false
end

-- ============================================================================
-- UCS MODE METHODS
-- ============================================================================

-- Toggle UCS mode on/off
function ItemTable:toggleUCSMode()
    self.ucs_mode = not self.ucs_mode
end

-- Set UCS mode
function ItemTable:setUCSMode(enabled)
    self.ucs_mode = enabled
end

-- Get UCS mode state
function ItemTable:isUCSMode()
    return self.ucs_mode
end

-- Get UCS status icon and color for an item
function ItemTable:getUCSStatusIcon(item)
    if not item then
        return "✗", 0xF90000FF -- Red
    end

    local status = item:getUCSStatus()

    if status == "complete" then
        return "✓", self.ucs_config.STATUS_COLORS and self.ucs_config.STATUS_COLORS.COMPLETE or 0x00FFBBFF
    elseif status == "incomplete" then
        return "⚠", self.ucs_config.STATUS_COLORS and self.ucs_config.STATUS_COLORS.INCOMPLETE or 0x00FFAAFF
    else
        return "✗", self.ucs_config.STATUS_COLORS and self.ucs_config.STATUS_COLORS.NOT_SET or 0xF90000FF
    end
end

-- Get active columns (includes UCS columns when UCS mode is on)
function ItemTable:getActiveColumns()
    local columns = {}

    -- Base columns (always visible)
    for _, col in ipairs(self.columns) do
        table.insert(columns, col)
    end

    -- UCS columns (only when UCS mode is enabled)
    if self.ucs_mode then
        -- Status column (always visible in UCS mode)
        table.insert(columns, "Status")

        -- Optional UCS columns based on config
        if self.ucs_config.COLUMNS then
            if self.ucs_config.COLUMNS.CATEGORY then
                table.insert(columns, "UCS Category")
            end
            if self.ucs_config.COLUMNS.FXNAME then
                table.insert(columns, "UCS FX Name")
            end
            if self.ucs_config.COLUMNS.KEYWORDS then
                table.insert(columns, "Keywords")
            end
            if self.ucs_config.COLUMNS.CREATOR then
                table.insert(columns, "Creator")
            end
            if self.ucs_config.COLUMNS.SOURCE then
                table.insert(columns, "Source")
            end
            if self.ucs_config.COLUMNS.USER_DATA then
                table.insert(columns, "User Data")
            end
        end
    end

    return columns
end

-- Get keywords display string (truncated)
function ItemTable:getKeywordsDisplay(item, max_length)
    max_length = max_length or 50

    if not item.ucs or not item.ucs.keywords or #item.ucs.keywords == 0 then
        return ""
    end

    local keywords_str = table.concat(item.ucs.keywords, ", ")

    if #keywords_str > max_length then
        return keywords_str:sub(1, max_length - 3) .. "..."
    end

    return keywords_str
end

-- Draw a single row (can be overridden)
function ItemTable:drawRow(ctx, item, row)
    -- Column 1: Index with optional checkbox
    -- reaper.ImGui_TableNextColumn(ctx)

    if self.show_checkbox then
        local changed, new_val = reaper.ImGui_Checkbox(ctx, '##fav' .. row, item.favorite or false)
        if changed and self.on_favorite_toggle then
            self.on_favorite_toggle(row, new_val)
        end
        reaper.ImGui_SameLine(ctx)
    end

    reaper.ImGui_Text(ctx, tostring(item.index))

    -- Column 2: Filename
    reaper.ImGui_TableNextColumn(ctx)
    reaper.ImGui_Text(ctx, Utils.GetFileNameFromPath(item.file))


    -- Column 3: Take Name (editable or static)
    reaper.ImGui_TableNextColumn(ctx)

    if self.editable_takename then
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        reaper.ImGui_SetNextItemAllowOverlap(ctx)
        local changed, new_name = reaper.ImGui_InputText(ctx, '##take' .. row, item.takeName or "")
        if changed and self.on_takename_edit then
            self.on_takename_edit(row, new_name)
        end
    else
        reaper.ImGui_Text(ctx, item.takeName or "")
    end

    -- UCS Columns (only shown when UCS mode is enabled)
    if self.ucs_mode then
        -- UCS Status Column (always visible)
        reaper.ImGui_TableNextColumn(ctx)
        local icon, color = self:getUCSStatusIcon(item)
        reaper.ImGui_TextColored(ctx, color, icon)

        -- Tooltip on hover
        if reaper.ImGui_IsItemHovered(ctx) then
            self:drawUCSStatusTooltip(ctx, item)
        end

        -- Category Column
        if self.ucs_config.COLUMNS and self.ucs_config.COLUMNS.CATEGORY then
            reaper.ImGui_TableNextColumn(ctx)

            if item.ucs and item.ucs.catid then
                -- Show current category
                local display_name = item.ucs.catid
                if self.ucs_database then
                    display_name = self.ucs_database:getDisplayName(item.ucs.catid)
                end
                reaper.ImGui_Text(ctx, display_name)
            else
                reaper.ImGui_TextDisabled(ctx, "(none)")
            end
        end

        -- FX Name Column
        if self.ucs_config.COLUMNS and self.ucs_config.COLUMNS.FXNAME then
            reaper.ImGui_TableNextColumn(ctx)

            if item.ucs then
                reaper.ImGui_SetNextItemWidth(ctx, -1)
                local changed, new_fxname = reaper.ImGui_InputText(ctx, '##ucs_fx' .. row, item.ucs.fxname or "")
                if changed then
                    item.ucs.fxname = new_fxname
                    if self.on_ucs_change then
                        self.on_ucs_change(row, item)
                    end
                end
            else
                reaper.ImGui_TextDisabled(ctx, "")
            end
        end

        -- Keywords Column
        if self.ucs_config.COLUMNS and self.ucs_config.COLUMNS.KEYWORDS then
            reaper.ImGui_TableNextColumn(ctx)

            local keywords_display = self:getKeywordsDisplay(item, 50)
            reaper.ImGui_Text(ctx, keywords_display)

            -- Tooltip shows all keywords
            if reaper.ImGui_IsItemHovered(ctx) and item.ucs and #item.ucs.keywords > 0 then
                reaper.ImGui_SetTooltip(ctx, table.concat(item.ucs.keywords, "\n"))
            end
        end

        -- Creator Column
        if self.ucs_config.COLUMNS and self.ucs_config.COLUMNS.CREATOR then
            reaper.ImGui_TableNextColumn(ctx)

            if item.ucs then
                reaper.ImGui_SetNextItemWidth(ctx, -1)
                local changed, new_creator = reaper.ImGui_InputText(ctx, '##ucs_creator' .. row,
                    item.ucs.creator_id or "")
                if changed then
                    item.ucs.creator_id = new_creator
                    if self.on_ucs_change then
                        self.on_ucs_change(row, item)
                    end
                end
            else
                reaper.ImGui_TextDisabled(ctx, "")
            end
        end

        -- Source Column
        if self.ucs_config.COLUMNS and self.ucs_config.COLUMNS.SOURCE then
            reaper.ImGui_TableNextColumn(ctx)

            if item.ucs then
                reaper.ImGui_SetNextItemWidth(ctx, -1)
                local changed, new_source = reaper.ImGui_InputText(ctx, '##ucs_source' .. row, item.ucs.source_id or "")
                if changed then
                    item.ucs.source_id = new_source
                    if self.on_ucs_change then
                        self.on_ucs_change(row, item)
                    end
                end
            else
                reaper.ImGui_TextDisabled(ctx, "")
            end
        end

        -- User Data Column
        if self.ucs_config.COLUMNS and self.ucs_config.COLUMNS.USER_DATA then
            reaper.ImGui_TableNextColumn(ctx)

            if item.ucs then
                reaper.ImGui_SetNextItemWidth(ctx, -1)
                local changed, new_desc = reaper.ImGui_InputText(ctx, '##ucs_user_data' .. row,
                    item.ucs.description or "")
                if changed then
                    item.ucs.description = new_desc
                    if self.on_ucs_change then
                        self.on_ucs_change(row, item)
                    end
                end
            else
                reaper.ImGui_TextDisabled(ctx, "")
            end
        end
    end
end

-- Draw UCS status tooltip
function ItemTable:drawUCSStatusTooltip(ctx, item)
    if not item then
        return
    end

    local status = item:getUCSStatus()

    if status == "not_set" then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_Text(ctx, "UCS Status: Not Set")
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Text(ctx, "No UCS metadata assigned")
        reaper.ImGui_Text(ctx, "")
        reaper.ImGui_TextDisabled(ctx, "Click to edit in UCS Editor")
        reaper.ImGui_EndTooltip(ctx)
    elseif status == "incomplete" then
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_Text(ctx, "UCS Status: Incomplete")
        reaper.ImGui_Separator(ctx)

        if item.ucs then
            if item.ucs.catid ~= "" then
                reaper.ImGui_Text(ctx, "✓ Category: " .. item.ucs.catid)
            else
                reaper.ImGui_Text(ctx, "✗ Category: (not set)")
            end

            if item.ucs.fxname ~= "" then
                reaper.ImGui_Text(ctx, "✓ FX Name: " .. item.ucs.fxname)
            else
                reaper.ImGui_Text(ctx, "✗ FX Name: (not set)")
            end

            if item.ucs.creator_id ~= "" then
                reaper.ImGui_Text(ctx, "✓ Creator: " .. item.ucs.creator_id)
            else
                reaper.ImGui_Text(ctx, "✗ Creator: (not set)")
            end

            if item.ucs.source_id ~= "" then
                reaper.ImGui_Text(ctx, "✓ Source: " .. item.ucs.source_id)
            else
                reaper.ImGui_Text(ctx, "✗ Source: (not set)")
            end
        end

        reaper.ImGui_Text(ctx, "")
        reaper.ImGui_TextDisabled(ctx, "Click to edit in UCS Editor")
        reaper.ImGui_EndTooltip(ctx)
    else -- complete
        reaper.ImGui_BeginTooltip(ctx)
        reaper.ImGui_Text(ctx, "UCS Status: Complete ✓")
        reaper.ImGui_Separator(ctx)

        if item.ucs then
            local cat_name = "Unknown"
            if self.ucs_database then
                cat_name = self.ucs_database:getDisplayName(item.ucs.catid)
            end

            reaper.ImGui_Text(ctx, "Category: " .. cat_name .. " (" .. item.ucs.catid .. ")")
            reaper.ImGui_Text(ctx, "FX Name: " .. item.ucs.fxname)
            reaper.ImGui_Text(ctx, "Creator: " .. item.ucs.creator_id)
            reaper.ImGui_Text(ctx, "Source: " .. item.ucs.source_id)

            if #item.ucs.keywords > 0 then
                reaper.ImGui_Text(ctx, "Keywords: " .. table.concat(item.ucs.keywords, ", "))
            end

            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "Full filename:")
            local filename = item:getUCSFilename()
            if filename then
                reaper.ImGui_Text(ctx, filename .. ".wav")
            end
        end

        reaper.ImGui_EndTooltip(ctx)
    end
end

-- Draw the complete table
-- Returns: clicked_row, double_clicked_row, marked_for_delete
function ItemTable:draw(ctx, items, width, height)
    if not items or #items == 0 then
        reaper.ImGui_Text(ctx, "No items")
        return nil, nil, nil
    end

    local clicked_row = nil
    local right_clicked_row = nil
    local double_clicked_row = nil
    local marked_for_delete = nil

    if not reaper.ImGui_BeginChild(ctx, self.id .. '_child', width, height, reaper.ImGui_ChildFlags_Border()) then
        return nil, nil, nil
    end

    -- Begin table
    local table_flags = reaper.ImGui_TableFlags_ScrollY() |
        reaper.ImGui_TableFlags_Resizable() |
        reaper.ImGui_TableFlags_SizingFixedFit()

    if self.ucs_mode then
        table_flags = table_flags | reaper.ImGui_TableFlags_ScrollX()
    end

    -- Get active columns (includes UCS columns when enabled)
    local active_columns = self:getActiveColumns()

    local table_w, table_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local table_x, table_y = reaper.ImGui_GetCursorScreenPos(ctx)

    if not reaper.ImGui_BeginTable(ctx, self.id .. '_table', #active_columns, table_flags, table_w, 0) then
        reaper.ImGui_EndChild(ctx)
        return nil, nil, nil
    end

    -- Setup columns
    for i, col_name in ipairs(active_columns) do
        local flags = self.column_flags[i] or reaper.ImGui_TableColumnFlags_WidthFixed()
        if i == 1 then
            flags = reaper.ImGui_TableColumnFlags_WidthFixed()
        end
        reaper.ImGui_TableSetupColumn(ctx, col_name, flags)
    end

    if self.ucs_mode then
        reaper.ImGui_TableHeadersRow(ctx)
    end

    -- Draw rows
    for row = 1, #items do
        if items[row] and self:shouldShowItem(items[row]) then
            reaper.ImGui_TableNextRow(ctx)
            reaper.ImGui_TableNextColumn(ctx)

            -- Selectable spanning all columns
            local is_selected = row == self.current_selected
            local rv = reaper.ImGui_Selectable(
                ctx,
                '##row' .. row,
                is_selected,
                reaper.ImGui_SelectableFlags_SpanAllColumns() | reaper.ImGui_SelectableFlags_AllowOverlap()
            )

            -- NEW: Make it draggable
            if reaper.ImGui_BeginDragDropSource(ctx) then
                -- Build payload of selected indices
                local selected = self:getSelectedIndices()
                if #selected == 0 then
                    -- If nothing multi-selected, drag this single item
                    selected = { row }
                end

                -- Convert to string payload: "1,2,3"
                local payload = table.concat(selected, ",")
                reaper.ImGui_SetDragDropPayload(ctx, "AUDIO_ITEMS", payload)

                -- Show drag preview
                if #selected == 1 then
                    reaper.ImGui_Text(ctx, "Dragging: " .. items[selected[1]].takeName or items[selected[1]].file)
                else
                    reaper.ImGui_Text(ctx, "Dragging " .. #selected .. " items")
                end

                reaper.ImGui_EndDragDropSource(ctx)
            end

            -- Draw selection highlight for multi-selected items
            if self:isRowSelected(row) and #self.selected_indices > 1 and reaper.ImGui_IsItemVisible(ctx) then
                local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
                local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)

                local draw_list = reaper.ImGui_GetForegroundDrawList(ctx)

                local scrollbar_size_w = reaper.ImGui_GetScrollMaxY(ctx) > 0 and reaper.ImGui_StyleVar_ScrollbarSize() or 0
                local scrollbar_sie_h = reaper.ImGui_GetScrollMaxX(ctx) > 0 and reaper.ImGui_StyleVar_ScrollbarSize() or 0
                
                local overlay_min_y = min_y < table_y and table_y or min_y
                local table_bounds_y = table_y + table_h - scrollbar_sie_h
                local overlay_max_y = max_y > table_bounds_y and table_bounds_y or max_y

                -- Draw tinted background overlay
                reaper.ImGui_DrawList_AddRectFilled(
                    draw_list,
                    table_x + 5, overlay_min_y,
                    table_x + table_w - scrollbar_size_w, overlay_max_y,
                    0xFFFF4444 -- Semi-transparent red tint
                )

                -- Draw red line on left edge
                reaper.ImGui_DrawList_AddRectFilled(
                    draw_list,
                    table_x, overlay_min_y,
                    table_x + 3, overlay_max_y,
                    0xFF4444FF -- Solid red bar on left edge
                )
            end

            -- Handle click with multi-select modifiers
            if rv then
                clicked_row = row

                -- Check modifier keys
                local ctrl_down = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
                local shift_down = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift())

                if ctrl_down then
                    -- CTRL+CLICK: Toggle this item in selection
                    if self:isRowSelected(row) then
                        self:removeFromSelection(row)
                    else
                        self:addToSelection(row)
                    end
                    self.last_clicked_index = row
                elseif shift_down and self.last_clicked_index > 0 then
                    -- SHIFT+CLICK: Select range from last clicked to current
                    self:selectRange(self.last_clicked_index, row, items)
                else
                    -- NORMAL CLICK: Select only this item
                    self:clearMultiSelection()
                    self:addToSelection(row)
                    self.last_clicked_index = row
                    self.current_selected = row
                    self.selected_item = items[row] -- NEW: Store the actual item
                end

                if self.on_click then
                    self.on_click(row, items[row])
                end
            end

            -- Handle double-click
            if reaper.ImGui_IsItemHovered(ctx) and
                reaper.ImGui_IsMouseDoubleClicked(ctx, reaper.ImGui_MouseButton_Left()) then
                double_clicked_row = row

                if self.on_double_click then
                    self.on_double_click(row, items[row])
                end
            end

            -- NEW: Handle right-click (ADD THIS)
            if reaper.ImGui_IsItemHovered(ctx) and
                reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Right()) then
                if self.on_right_click then
                    self.on_right_click(row, items[row])
                end
            end

            -- Handle delete with Alt key
            local is_delete = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt())
            if is_delete and rv then
                marked_for_delete = row
            end

            -- Draw the actual row content
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_SetNextItemAllowOverlap(ctx)
            self:drawRow(ctx, items[row], row)
        end
    end

    reaper.ImGui_EndTable(ctx)
    reaper.ImGui_EndChild(ctx)

    return clicked_row, double_clicked_row, marked_for_delete, right_clicked_row
end

-- Draw a simple table (for project items - non-editable, simpler)
function ItemTable:drawSimple(ctx, items, width, height)
    if not items or #items == 0 then
        reaper.ImGui_Text(ctx, "No items selected")
        return nil, nil
    end

    local clicked_row = nil
    local double_clicked_row = nil

    if not reaper.ImGui_BeginChild(ctx, self.id .. '_child', width, height, reaper.ImGui_ChildFlags_Border()) then
        return nil, nil
    end

    local table_flags = reaper.ImGui_TableFlags_ScrollY() |
        reaper.ImGui_TableFlags_Resizable() |
        reaper.ImGui_TableFlags_SizingFixedFit()

    if not reaper.ImGui_BeginTable(ctx, self.id .. '_table', #self.columns, table_flags, reaper.ImGui_GetContentRegionAvail(ctx), 0) then
        reaper.ImGui_EndChild(ctx)
        return nil, nil
    end

    -- Setup columns
    for i, col_name in ipairs(self.columns) do
        local flags = self.column_flags[i] or reaper.ImGui_TableColumnFlags_WidthStretch()
        if i == 1 then
            flags = reaper.ImGui_TableColumnFlags_WidthFixed()
        end
        reaper.ImGui_TableSetupColumn(ctx, col_name, flags)
    end

    -- reaper.ImGui_TableHeadersRow(ctx)

    -- Draw rows
    for row = 1, #items do
        if items[row] then
            reaper.ImGui_TableNextRow(ctx)
            reaper.ImGui_TableNextColumn(ctx)

            local is_selected = row == self.current_selected
            local rv = reaper.ImGui_Selectable(
                ctx,
                tostring(items[row].index),
                is_selected,
                reaper.ImGui_SelectableFlags_SpanAllColumns() | reaper.ImGui_SelectableFlags_AllowOverlap()
            )

            if rv then
                clicked_row = row
                self.current_selected = row

                if self.on_click then
                    self.on_click(row)
                end
            end

            -- Filename column
            reaper.ImGui_TableNextColumn(ctx)
            reaper.ImGui_Text(ctx, Utils.GetFileNameFromPath(items[row].file))

            -- Take name column (editable for project items)
            reaper.ImGui_TableNextColumn(ctx)
            reaper.ImGui_SetNextItemWidth(ctx, -1)
            reaper.ImGui_SetNextItemAllowOverlap(ctx)
            local changed, new_name = reaper.ImGui_InputText(ctx, '##take' .. row, items[row].takeName or "")

            if changed and self.on_takename_edit then
                self.on_takename_edit(row, new_name)
            end
        end
    end

    reaper.ImGui_EndTable(ctx)
    reaper.ImGui_EndChild(ctx)

    return clicked_row, double_clicked_row
end

-- Get filtered item count
function ItemTable:getFilteredCount(items)
    if not items then return 0 end

    local count = 0
    for _, item in ipairs(items) do
        if self:shouldShowItem(item) then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- MULTI-SELECT METHODS
-- ============================================================================

-- Check if a row is selected
-- @param index (number) - Row index
-- @return (boolean) - True if selected

function ItemTable:isRowSelected(index)
    for _, selected_idx in ipairs(self.selected_indices) do
        if selected_idx == index then
            return true
        end
    end
    return false
end

-- Add a row to selection
-- @param index (number) - Row index

function ItemTable:addToSelection(index)
    if not self:isRowSelected(index) then
        table.insert(self.selected_indices, index)
    end
end

-- Remove a row from selection
-- @param index (number) - Row index

function ItemTable:removeFromSelection(index)
    for i, selected_idx in ipairs(self.selected_indices) do
        if selected_idx == index then
            table.remove(self.selected_indices, i)
            return
        end
    end
end

-- Clear all selections
function ItemTable:clearMultiSelection()
    self.selected_indices = {}
    self.last_clicked_index = -1
end

-- Select a range of rows
-- @param start_idx (number) - Start of range
-- @param end_idx (number) - End of range

function ItemTable:selectRange(start_idx, end_idx, items)
    -- Clear current selection
    self.selected_indices = {}

    -- Ensure start <= end
    local from = math.min(start_idx, end_idx)
    local to = math.max(start_idx, end_idx)

    -- Add only VISIBLE indices in range (respecting search filter)
    for i = from, to do
        if items and items[i] and self:shouldShowItem(items[i]) then
            table.insert(self.selected_indices, i)
        elseif not items then
            -- Fallback: if items not provided, add all (backward compatible)
            table.insert(self.selected_indices, i)
        end
    end
end

-- Get all selected indices
-- @return (table) - Array of selected indices

function ItemTable:getSelectedIndices()
    return self.selected_indices
end

-- Get count of selected items
-- @return (number) - Count

function ItemTable:getSelectedCount()
    return #self.selected_indices
end

return ItemTable
