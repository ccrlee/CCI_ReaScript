-- UCSEditor.lua
-- Main UCS metadata editor panel with batch editing support

local UCSEditor = {}
UCSEditor.__index = UCSEditor

-- Load dependencies
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"
local UCSCategoryPicker = require("UCSCategoryPicker")
local UCSMetadata = require("UCSMetadata")
local Utils = require ("Utils")


-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

function UCSEditor.new(ucs_database, config)
    config = config or {}
    
    local self = setmetatable({}, UCSEditor)
    
    self.database = ucs_database
    self.config = config
    
    -- UI State
    self.is_expanded = config.start_expanded or false
    self.selected_items = {}  -- Array of AudioItem objects
    
    -- Working data (edited values)
    self.edit_catid = ""
    self.edit_fxname = ""
    self.edit_creator = config.default_creator or ""
    self.edit_source = config.default_source or ""
    self.edit_user_category = ""
    self.edit_vendor_category = ""
    self.edit_user_data = ""
    self.edit_keywords = {}
    self.edit_description = ""
    
    -- Batch editing flags
    self.batch_apply_category = true
    self.batch_apply_creator_source = true
    self.batch_keep_individual_fxnames = true
    self.number_fxnames = false

    -- Components
    self.category_picker = UCSCategoryPicker.new(ucs_database, {
        height = 400,
    })
    
    -- Keyword suggestions (from current category)
    self.available_keywords = {}
    self.show_all_keywords = false
    
    -- Apply Button Callback
    self.apply_callback = nil

    return self
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Set selected items to edit
-- @param items (table) - Array of AudioItem objects
function UCSEditor:setItems(items)
    self.selected_items = items or {}
    
    -- Load data from first item (if exists)
    if #self.selected_items > 0 then
        self:loadFromItem(self.selected_items[1])
    else
        self:clear()
    end
end

-- Toggle expanded/collapsed state
function UCSEditor:toggleExpanded()
    self.is_expanded = not self.is_expanded
end

-- Set expanded state
-- @param expanded (boolean) - True to expand
function UCSEditor:setExpanded(expanded)
    self.is_expanded = expanded
end

-- Check if expanded
-- @return (boolean) - True if expanded
function UCSEditor:isExpanded()
    return self.is_expanded
end

-- ============================================================================
-- DATA LOADING
-- ============================================================================

-- Load UCS data from an AudioItem
-- @param item (AudioItem) - Item to load from
function UCSEditor:loadFromItem(item)
    if not item then
        self:clear()
        return
    end
    
    -- Load from item's UCS data (or use defaults)
    if item.ucs then
        self.edit_catid = item.ucs.catid
        self.edit_fxname = item.ucs.fxname
        self.edit_creator = item.ucs.creator_id
        self.edit_source = item.ucs.source_id
        self.edit_user_category = item.ucs.user_category
        self.edit_vendor_category = item.ucs.vendor_category
        self.edit_user_data = item.ucs.user_data
        self.edit_keywords = item.ucs.keywords or {}
        self.edit_description = item.ucs.description
        
        -- Update category picker
        self.category_picker:setSelected(item.ucs.catid)
    else
        -- Use defaults
        self.edit_catid = ""
        self.edit_fxname = ""
        self.edit_creator = self.config.default_creator or ""
        self.edit_source = self.config.default_source or ""
        self.edit_user_category = ""
        self.edit_vendor_category = ""
        self.edit_user_data = ""
        self.edit_keywords = {}
        self.edit_description = ""
        
        self.category_picker:setSelected("")
    end
    
    -- Update keyword suggestions based on category
    self:updateKeywordSuggestions()
end

-- Clear all edit fields
function UCSEditor:clear()
    self.edit_catid = ""
    self.edit_fxname = ""
    self.edit_creator = self.config.default_creator or ""
    self.edit_source = self.config.default_source or ""
    self.edit_user_category = ""
    self.edit_vendor_category = ""
    self.edit_user_data = ""
    self.edit_keywords = {}
    self.edit_description = ""
    self.category_picker:setSelected("")
    self.available_keywords = {}
end

-- ============================================================================
-- KEYWORD MANAGEMENT
-- ============================================================================

-- Update keyword suggestions based on current category
function UCSEditor:updateKeywordSuggestions()
    if self.edit_catid == "" or not self.database then
        self.available_keywords = {}
        return
    end
    
    self.available_keywords = self.database:getSynonyms(self.edit_catid)
end

-- Add keyword
-- @param keyword (string) - Keyword to add
-- @return (boolean) - True if added
function UCSEditor:addKeyword(keyword)
    if not keyword or keyword == "" then
        return false
    end
    
    -- Check if already exists (case-insensitive)
    local keyword_lower = keyword:lower()
    for _, kw in ipairs(self.edit_keywords) do
        if kw:lower() == keyword_lower then
            return false
        end
    end
    
    table.insert(self.edit_keywords, keyword)
    return true
end

-- Remove keyword
-- @param keyword (string) - Keyword to remove
function UCSEditor:removeKeyword(keyword)
    for i, kw in ipairs(self.edit_keywords) do
        if kw == keyword then
            table.remove(self.edit_keywords, i)
            return true
        end
    end
    return false
end

-- ============================================================================
-- APPLY CHANGES
-- ============================================================================

-- Apply edited values to selected items
-- @return (boolean, string) - Success and message
function UCSEditor:apply()
    if #self.selected_items == 0 then
        return false, "No items selected"
    end
    
    -- Validate
    if self.edit_catid == "" then
        return false, "Category is required"
    end
    
    -- For batch editing, check FX Name requirement
    if #self.selected_items > 1 and not self.batch_keep_individual_fxnames then
        if self.edit_fxname == "" then
            return false, "FX Name is required when overwriting all items"
        end
    end
    
    -- Apply to each item
    local count = 0
    for index, item in ipairs(self.selected_items) do
        local ucs = item:getOrCreateUCS()
        
        -- Category (always apply in batch)
        if self.batch_apply_category or #self.selected_items == 1 then
            ucs.catid = self.edit_catid
            
            -- Update category/subcategory from database
            local cat = self.database:getCategory(self.edit_catid)
            if cat then
                ucs.category = cat.category
                ucs.subcategory = cat.subcategory
            end
        end
        
        -- FX Name (batch behavior)
        if #self.selected_items == 1 then
            ucs.fxname = self.edit_fxname
        elseif not self.batch_keep_individual_fxnames then
            local new_name = self.edit_fxname

            if self.number_fxnames then 
                ucs.fxname = new_name .. string.format(" %02d", index) 
            else
                ucs.fxname = new_name
            end
            
        else
            if index == 1 then ucs.fxname = self.edit_fxname end
            -- else: edit first and keep individual FX names
        end
        
        -- Creator/Source (always apply in batch)
        if self.batch_apply_creator_source or #self.selected_items == 1 then
            ucs.creator_id = self.edit_creator
            ucs.source_id = self.edit_source
        end
        
        -- Optional fields (always apply)
        ucs.user_category = self.edit_user_category
        ucs.vendor_category = self.edit_vendor_category
        ucs.user_data = self.edit_user_data
        
        -- Keywords (always apply)
        ucs.keywords = {}
        for _, kw in ipairs(self.edit_keywords) do
            table.insert(ucs.keywords, kw)
        end
        
        -- Description (always apply)
        ucs.description = self.edit_description
        
        count = count + 1
    end
    
    return true, string.format("Applied UCS metadata to %d item%s", count, count == 1 and "" or "s")
end

-- ============================================================================
-- DRAWING
-- ============================================================================

-- Draw the UCS editor panel
-- @param ctx - ImGui context
-- @param width (number) - Available width
-- @param height (number) - Available height
-- @return (boolean) - True if Apply was clicked
function UCSEditor:draw(ctx, width, height)
    local applied = false
    
    -- Header bar (always visible)
    if reaper.ImGui_Button(ctx, self.is_expanded and "▼ UCS METADATA EDITOR" or "▶ UCS METADATA EDITOR") then
        self:toggleExpanded()
    end
    
    reaper.ImGui_SameLine(ctx)
    
    -- Item count
    local item_count = #self.selected_items
    if item_count == 0 then
        reaper.ImGui_TextDisabled(ctx, "Select one or more items to edit")
    elseif item_count == 1 then
        reaper.ImGui_Text(ctx, "Editing: " .. self.selected_items[1]:getDisplayName())
    else
        reaper.ImGui_Text(ctx, string.format("Editing: %d items selected", item_count))
    end
    
    reaper.ImGui_SameLine(ctx, width - 120)
    
    -- Collapse button
    if reaper.ImGui_Button(ctx, self.is_expanded and "Collapse ▲" or "Expand ▼", 120, 0) then
        self:toggleExpanded()
    end
    
    -- Only draw content if expanded
    if not self.is_expanded then
        return applied
    end
    
    reaper.ImGui_Separator(ctx)
    
    -- Disable if no items selected
    if item_count == 0 then
        return applied
    end
    
    -- Main content area
    if reaper.ImGui_BeginChild(ctx, "##ucs_editor_content", width, height) then
        
        -- Two-column layout
        local col1_width = width * 0.65
        local col2_width = width * 0.35
        local gutter = 50

        reaper.ImGui_BeginGroup(ctx)
        
        -- ====================================================================
        -- LEFT COLUMN: Required Fields
        -- ====================================================================
        
        reaper.ImGui_TextColored(ctx, 0xFFFFAAAA, "REQUIRED FIELDS")
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Category
        reaper.ImGui_Text(ctx, "Category:")
        reaper.ImGui_SetNextItemWidth(ctx, col1_width - gutter)
        if self.category_picker:draw(ctx, "##category", col1_width - gutter) then
            self.edit_catid = self.category_picker:getSelected()
            self:updateKeywordSuggestions()
        end
        
        -- Batch checkbox for category
        if item_count > 1 then
            local changed, new_val = reaper.ImGui_Checkbox(ctx, "☑ Apply to all items", self.batch_apply_category)
            if changed then
                self.batch_apply_category = new_val
            end
        end
        
        reaper.ImGui_Spacing(ctx)
        
        -- FX Name
        reaper.ImGui_Text(ctx, "FX Name:")
        reaper.ImGui_SetNextItemWidth(ctx, col1_width - (gutter*2))
        local changed, new_fxname = reaper.ImGui_InputText(ctx, "##fxname", self.edit_fxname)
        if changed then
            self.edit_fxname = new_fxname
        end
        
        -- Character count
        local char_count = #self.edit_fxname
        local max_chars = self.config.max_fxname_length or 25
        local count_color = char_count > max_chars and 0xFF2300FF or 0xCCCCCC88
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_TextColored(ctx, count_color, string.format("%d/%d", char_count, max_chars))
        
        if char_count > max_chars then
            reaper.ImGui_SameLine(ctx)
            reaper.ImGui_TextColored(ctx, 0xFFFF00FF, "⚠")
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx, "FX Name exceeds recommended " .. max_chars .. " characters")
            end
        end
        
        -- Batch FX Name options
        if item_count > 1 then
            reaper.ImGui_Spacing(ctx)
            
            local changed1, new_val1 = reaper.ImGui_Checkbox(ctx, "○ Keep individual FX Names", self.batch_keep_individual_fxnames)
            if changed1 then
                self.batch_keep_individual_fxnames = new_val1
            end
            
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx, "Each item keeps its existing FX Name (or stays empty)")
            end
            
            reaper.ImGui_SameLine(ctx)

            local changed2, new_val2 = reaper.ImGui_Checkbox(ctx, "Number Fx Names", self.number_fxnames)
            if changed2 then
                self.number_fxnames = new_val2
            end
        end
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Creator & Source
        reaper.ImGui_Text(ctx, "Creator ID:")
        reaper.ImGui_SameLine(ctx, 100)
        reaper.ImGui_SetNextItemWidth(ctx, 100)
        local changed3, new_creator = reaper.ImGui_InputText(ctx, "##creator", self.edit_creator)
        if changed3 then
            self.edit_creator = new_creator
        end
        
        reaper.ImGui_SameLine(ctx, 230)
        reaper.ImGui_Text(ctx, "Source ID:")
        reaper.ImGui_SameLine(ctx, 320)
        reaper.ImGui_SetNextItemWidth(ctx, 150)
        local changed4, new_source = reaper.ImGui_InputText(ctx, "##source", self.edit_source)
        if changed4 then
            self.edit_source = new_source
        end

        -- Batch checkbox for creator/source
        if item_count > 1 then
            local changed5, new_val5 = reaper.ImGui_Checkbox(ctx, "☑ Apply Creator/Source to all items", self.batch_apply_creator_source)
            if changed5 then
                self.batch_apply_creator_source = new_val5
            end
        end
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- KEYWORDS
        -- ====================================================================
        
        reaper.ImGui_TextColored(ctx, 0xFFFFAAAA, "KEYWORDS")
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, col1_width - gutter)

        local retval, newKeyword = reaper.ImGui_InputText(ctx, '##keywords', '', reaper.ImGui_InputTextFlags_EnterReturnsTrue())

        if retval then
            -- keyword form text box
            local keywords = Utils.split(newKeyword, ",")
            if #keywords > 1 then
                for index, value in ipairs(keywords) do
                    self:addKeyword(value)
                end
            else
                self:addKeyword(newKeyword)
            end
        end

        -- Selected keywords (tag chips)
        reaper.ImGui_Text(ctx, "Selected:")
        reaper.ImGui_SameLine(ctx)
        
        if #self.edit_keywords == 0 then
            reaper.ImGui_TextDisabled(ctx, "(none)")
        else
            -- Draw keyword chips
            for i, keyword in ipairs(self.edit_keywords) do
                if i > 1 and (i % 9 ~= 1) then
                    reaper.ImGui_SameLine(ctx)
                end
                
                if reaper.ImGui_SmallButton(ctx, keyword .. " ×") then
                    self:removeKeyword(keyword)
                end
            end
        end
        
        reaper.ImGui_Spacing(ctx)
        
        -- Quick keyword suggestions
        if #self.available_keywords > 0 then
            reaper.ImGui_Text(ctx, "Quick suggestions from " .. self.edit_catid .. ":")
            
            local max_show = self.show_all_keywords and #self.available_keywords or (self.config.max_keyword_suggestions or 8)
            local shown = 0
            
            for i, keyword in ipairs(self.available_keywords) do
                if shown >= max_show then
                    break
                end
                
                -- Check if already selected
                local already_selected = false
                for _, kw in ipairs(self.edit_keywords) do
                    if kw:lower() == keyword:lower() then
                        already_selected = true
                        break
                    end
                end
                
                if not already_selected then
                    if shown > 0 and not self.show_all_keywords and i > 1 then
                        reaper.ImGui_SameLine(ctx)
                    elseif (1 < i and i < 8) or (shown > 0 and (shown % 9 ~= 1)) then
                        reaper.ImGui_SameLine(ctx)
                    end
                    
                    if reaper.ImGui_SmallButton(ctx, "+ " .. keyword) then
                        self:addKeyword(keyword)
                    end
                    
                    shown = shown + 1
                end
            end
            
            -- More button
            if #self.available_keywords >= max_show then
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x4300FFC9)
                if reaper.ImGui_SmallButton(ctx, self.show_all_keywords and "Less ▲" or "More ▼") then
                    self.show_all_keywords = not self.show_all_keywords
                end
                reaper.ImGui_PopStyleColor(ctx, 1)
            end
        end
        
        reaper.ImGui_EndGroup(ctx)
        
        -- ====================================================================
        -- RIGHT COLUMN: Preview & Actions
        -- ====================================================================
        
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_BeginGroup(ctx)
        
        -- ====================================================================
        -- DESCRIPTION
        -- ====================================================================
        reaper.ImGui_TextColored(ctx, 0xFFFFAAAA, "DESCRIPTION (optional)")
        reaper.ImGui_Spacing(ctx)
        
        reaper.ImGui_SetNextItemWidth(ctx, col2_width)
        local changed6, new_desc = reaper.ImGui_InputTextMultiline(
            ctx, 
            "##description", 
            self.edit_description, 
            col2_width, 
            60
        )
        if changed6 then
            self.edit_description = new_desc
        end

        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_TextColored(ctx, 0xFFFFAAAA, "PREVIEW")
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Build preview filename
        local preview_ucs = UCSMetadata.new({
            catid = self.edit_catid,
            fxname = self.edit_fxname,
            creator_id = self.edit_creator,
            source_id = self.edit_source,
            user_category = self.edit_user_category,
            vendor_category = self.edit_vendor_category,
            user_data = self.edit_user_data,
        })
        
        local preview_filename = preview_ucs:buildFilename(self.number_fxnames, #self.selected_items)

        if preview_filename then
            -- Add .wav extension for preview
            preview_filename = preview_filename .. ".wav"
            
            reaper.ImGui_TextWrapped(ctx, preview_filename)
            
            -- Validation status
            reaper.ImGui_Spacing(ctx)
            local valid, msg = preview_ucs:isValid()
            if valid then
                reaper.ImGui_TextColored(ctx, 0xFF00FF00, "✓ Valid")
            else
                reaper.ImGui_TextColored(ctx, 0xFFFF0000, "✗ " .. msg)
            end
        else
            reaper.ImGui_TextDisabled(ctx, "(fill in fields to see preview)")
        end
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- Apply button
        local can_apply = self.edit_catid ~= ""
        if not can_apply then
            reaper.ImGui_BeginDisabled(ctx)
        end
        
        local apply_text = item_count > 1 and ("Apply to " .. item_count .. " items") or "Apply"
        if reaper.ImGui_Button(ctx, apply_text, col2_width, 30) then
            local success, msg = self:apply()
            if success then
                applied = true
                if item_count > 1 then    
                    reaper.ShowMessageBox(msg, 'Success', 0)
                end
            else
                -- Show error (in real implementation, you'd show a popup)
                reaper.ShowConsoleMsg("UCS Apply Error: " .. msg)
            end
        end
        
        if not can_apply then
            reaper.ImGui_EndDisabled(ctx)
        end
        
        -- Cancel button
        if reaper.ImGui_Button(ctx, "Cancel", col2_width, 0) then
            -- Reload from first item
            if #self.selected_items > 0 then
                self:loadFromItem(self.selected_items[1])
            end
        end
        
        -- Clear button
        if reaper.ImGui_Button(ctx, "Clear All", col2_width, 0) then
            self:clear()
        end
        
        reaper.ImGui_EndGroup(ctx)
        
        reaper.ImGui_EndChild(ctx)
    end
    
    return applied
end

return UCSEditor