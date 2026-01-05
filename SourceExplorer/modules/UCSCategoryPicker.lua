-- UCSCategoryPicker.lua
-- Searchable category picker with visual hierarchy for UCS categories

local UCSCategoryPicker = {}
UCSCategoryPicker.__index = UCSCategoryPicker

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

function UCSCategoryPicker.new(ucs_database, config)
    config = config or {}
    
    local self = setmetatable({}, UCSCategoryPicker)
    
    self.database = ucs_database
    self.search_text = ""
    self.selected_catid = config.selected_catid or ""
    self.is_open = false
    self.height = config.height or 400
    self.width = config.width or 300
    
    -- Collapsed state for category groups
    self.collapsed_categories = {}
    
    return self
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Set selected category
-- @param catid (string) - CatID to select
function UCSCategoryPicker:setSelected(catid)
    self.selected_catid = catid or ""
    
    -- Add to recent
    if catid and catid ~= "" and self.database then
        self.database:addRecent(catid)
    end
end

-- Get selected category
-- @return (string) - Selected CatID
function UCSCategoryPicker:getSelected()
    return self.selected_catid
end

-- Get selected category data
-- @return (table) - Category data or nil
function UCSCategoryPicker:getSelectedCategory()
    if not self.database or self.selected_catid == "" then
        return nil
    end
    
    return self.database:getCategory(self.selected_catid)
end

-- ============================================================================
-- DRAWING
-- ============================================================================

-- Draw the category picker dropdown
-- @param ctx - ImGui context
-- @param label (string) - Label for the combo
-- @param width (number, optional) - Width of dropdown
-- @return (boolean) - True if selection changed
function UCSCategoryPicker:draw(ctx, label, width)
    if not self.database or not self.database:isLoaded() then
        reaper.ImGui_Text(ctx, "UCS Database not loaded")
        return false
    end
    
    local changed = false
    
    -- Get display text for current selection
    local display_text = self:getDisplayText()
    
    -- Set width if specified
    if width then
        reaper.ImGui_SetNextItemWidth(ctx, width)
    end
    
    -- Draw combo box
    if reaper.ImGui_BeginCombo(ctx, label, display_text) then
        self.is_open = true
        
        -- Search box
        reaper.ImGui_SetNextItemWidth(ctx, -1)
        local search_changed, new_search = reaper.ImGui_InputTextWithHint(
            ctx, 
            "##search", 
            "🔍 Search categories or synonyms...", 
            self.search_text
        )
        
        if search_changed then
            self.search_text = new_search
        end
        
        reaper.ImGui_Separator(ctx)
        
        -- Results area
        if reaper.ImGui_BeginChild(ctx, "##category_list", -1, self.height) then
            
            if self.search_text == "" then
                -- Show recent + all categories (grouped)
                changed = self:drawRecent(ctx) or changed
                reaper.ImGui_Separator(ctx)
                changed = self:drawGrouped(ctx) or changed
            else
                -- Show search results
                changed = self:drawSearchResults(ctx) or changed
            end
            
            reaper.ImGui_EndChild(ctx)
        end
        
        reaper.ImGui_EndCombo(ctx)
    else
        self.is_open = false
    end
    
    return changed
end

-- ============================================================================
-- DRAWING HELPERS
-- ============================================================================

-- Get display text for current selection
-- @return (string) - Display text
function UCSCategoryPicker:getDisplayText()
    if self.selected_catid == "" then
        return "(none)"
    end
    
    local cat = self:getSelectedCategory()
    if not cat then
        return self.selected_catid
    end
    
    return cat.catid .. " - " .. cat.category .. "-" .. cat.subcategory
end

-- Draw recent categories section
-- @param ctx - ImGui context
-- @return (boolean) - True if selection changed
function UCSCategoryPicker:drawRecent(ctx)
    local recent = self.database:getRecent()
    
    if #recent == 0 then
        return false
    end
    
    reaper.ImGui_TextDisabled(ctx, "Recent:")
    
    local changed = false
    
    for _, cat in ipairs(recent) do
        if self:drawCategoryItem(ctx, cat, false) then
            self:setSelected(cat.catid)
            reaper.ImGui_CloseCurrentPopup(ctx)
            changed = true
        end
    end
    
    return changed
end

-- Draw grouped categories (hierarchical)
-- @param ctx - ImGui context
-- @return (boolean) - True if selection changed
function UCSCategoryPicker:drawGrouped(ctx)
    reaper.ImGui_TextDisabled(ctx, "All Categories:")
    
    local main_categories = self.database:getMainCategories()
    local changed = false
    
    for _, main_cat in ipairs(main_categories) do
        local is_collapsed = self.collapsed_categories[main_cat]
        
        -- Get subcategories
        local subcats = self.database:getSubcategories(main_cat)
        local count = #subcats
        
        -- Draw tree node for main category
        local label = string.format("📁 %s (%d)", main_cat, count)
        
        local flags = reaper.ImGui_TreeNodeFlags_SpanFullWidth()
        if not is_collapsed then
            flags = flags | reaper.ImGui_TreeNodeFlags_DefaultOpen()
        end
        
        local open = reaper.ImGui_TreeNodeEx(ctx, main_cat, label, flags)
        
        if open then
            self.collapsed_categories[main_cat] = false
            
            -- Draw subcategories (indented)
            for _, cat in ipairs(subcats) do
                reaper.ImGui_Indent(ctx)
                if self:drawCategoryItem(ctx, cat, true) then
                    self:setSelected(cat.catid)
                    reaper.ImGui_CloseCurrentPopup(ctx)
                    changed = true
                end
                reaper.ImGui_Unindent(ctx)
            end
            
            reaper.ImGui_TreePop(ctx)
        else
            self.collapsed_categories[main_cat] = true
        end
    end
    
    return changed
end

-- Draw search results (flat list)
-- @param ctx - ImGui context
-- @return (boolean) - True if selection changed
function UCSCategoryPicker:drawSearchResults(ctx)
    local results = self.database:search(self.search_text)
    
    if #results == 0 then
        reaper.ImGui_TextDisabled(ctx, "No matches found")
        return false
    end
    
    reaper.ImGui_TextDisabled(ctx, string.format("Results (%d):", #results))
    
    local changed = false
    
    for _, cat in ipairs(results) do
        if self:drawCategoryItem(ctx, cat, false) then
            self:setSelected(cat.catid)
            reaper.ImGui_CloseCurrentPopup(ctx)
            changed = true
        end
    end
    
    return changed
end

-- Draw a single category item (selectable)
-- @param ctx - ImGui context
-- @param cat (table) - Category data
-- @param show_full (boolean) - Show full category-subcategory
-- @return (boolean) - True if clicked
function UCSCategoryPicker:drawCategoryItem(ctx, cat, show_full)
    local is_selected = (self.selected_catid == cat.catid)
    
    -- Build display text
    local display_text
    if show_full then
        display_text = string.format("   %s - %s", cat.catid, cat.subcategory)
    else
        display_text = string.format("%s - %s-%s", cat.catid, cat.category, cat.subcategory)
    end
    
    -- Draw selectable
    local clicked = reaper.ImGui_Selectable(ctx, display_text, is_selected)
    
    -- Tooltip with explanation
    if reaper.ImGui_IsItemHovered(ctx) and cat.explanation ~= "" then
        reaper.ImGui_SetTooltip(ctx, cat.explanation)
    end
    
    return clicked
end

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Check if picker is currently open
-- @return (boolean) - True if open
function UCSCategoryPicker:isOpen()
    return self.is_open
end

-- Clear search
function UCSCategoryPicker:clearSearch()
    self.search_text = ""
end

-- Get display name for a catid (without opening picker)
-- @param catid (string) - CatID to lookup
-- @return (string) - Display name
function UCSCategoryPicker:getDisplayNameFor(catid)
    if not catid or catid == "" then
        return "(none)"
    end
    
    local cat = self.database:getCategory(catid)
    if not cat then
        return catid
    end
    
    return cat.category .. "-" .. cat.subcategory
end

return UCSCategoryPicker