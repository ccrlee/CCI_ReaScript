-- CollectionPicker.lua
-- Popup UI component for assigning items to collections
--
-- RESPONSIBILITIES:
-- 1. Display list of all collections
-- 2. Show checkmarks for collections item is already in
-- 3. Toggle item membership on click
-- 4. Allow creating new collections
-- 5. Show hierarchy (indented children)
--
-- DESIGN: Modal Dialog Pattern
-- - Blocks interaction with main UI while open
-- - Clear action (checkboxes)
-- - Easy to dismiss (close button or click outside)

local CollectionPicker = {}
CollectionPicker.__index = CollectionPicker

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

-- Create a new CollectionPicker
-- @param collection_manager (CollectionManager) - The manager to work with
-- @param options (table, optional) - Configuration options
--   - show_hierarchy (boolean) - Show indented tree or flat list
--   - allow_new_collection (boolean) - Show "New Collection" option
--   - modal (boolean) - Use modal popup (blocks other UI)
--
-- DESIGN DECISION: Why separate from CollectionTree?
-- - Different interaction model (checkboxes vs selection)
-- - Different visual layout (flat list works better)
-- - Can be used in different contexts (not just sidebar)

function CollectionPicker.new(collection_manager, options)
    options = options or {}
    
    local self = setmetatable({}, CollectionPicker)
    
    -- REFERENCE TO DATA
    self.manager = collection_manager
    
    -- UI OPTIONS
    self.show_hierarchy = options.show_hierarchy ~= false     -- Default true
    self.allow_new_collection = options.allow_new_collection ~= false  -- Default true
    self.modal = options.modal ~= false                       -- Default true (modal)
    
    -- STATE
    self.is_open = false
    self.current_item = nil  -- AudioItem being edited
    self.popup_id = "CollectionPickerPopup"
    self.current_items = {}
    self.is_bulk = false
    
    -- INLINE NEW COLLECTION STATE (Solution D)
    self.inline_new_collection = false  -- Show inline input instead of dialog
    self.new_collection_name = ""
    
    -- AUTO-DESELECT OPTION
    self.clear_selection_on_close = true  -- Default: clear selection after closing
    
    return self
end

-- ============================================================================
-- POPUP CONTROL
-- ============================================================================

-- Open the picker for a specific item
-- @param item (AudioItem) - The item to edit
--
-- USAGE:
--   picker:open(my_audio_item)
--   -- Later in draw loop:
--   picker:draw(ctx)

function CollectionPicker:open(item)
    if not item then return end
    
    self.current_item = item
    self.is_open = true
    
    -- Tell ImGui to open the popup next frame
    -- Must be called before BeginPopup in the same frame
    -- But we'll call it in draw() to ensure timing is correct
end

-- Close the picker
function CollectionPicker:close()
    self.is_open = false
    self.current_item = nil
    self.current_items = {}
    self.is_bulk = false
end

-- Check if picker is open
-- @return (boolean)
function CollectionPicker:isOpen()
    return self.is_open
end

-- Get current item being edited
-- @return (AudioItem or nil)
function CollectionPicker:getCurrentItem()
    return self.current_item
end

-- ============================================================================
-- MAIN DRAWING METHOD
-- ============================================================================

-- Draw the collection picker popup
-- @param ctx (ImGui_Context) - ImGui context
-- @return (boolean, boolean) - changes_made, should_clear_selection
--
-- USAGE: Call this every frame in your main loop
--   local changed, should_clear = picker:draw(ctx)
--   if changed then
--       SaveData()  -- Save changes
--   end
--   if should_clear then
--       table:clearMultiSelection()  -- Clear selection
--   end
--
-- IMPORTANT: This handles opening the popup internally
-- You just need to call open() to trigger it, then call draw() every frame

function CollectionPicker:draw(ctx)
    local was_open = self.is_open
    local was_bulk = self.is_bulk
    local should_clear = self.clear_selection_on_close
    
    if not self.is_open then
        return false, false
    end
    
    local changes_made = false
    
    -- OPEN POPUP (if needed)
    -- This must be called before BeginPopup
    if self.is_open and not reaper.ImGui_IsPopupOpen(ctx, self.popup_id) then
        reaper.ImGui_OpenPopup(ctx, self.popup_id)
    end
    
    -- DRAW POPUP
    if self.modal then
        changes_made = self:drawModalPopup(ctx)
    else
        changes_made = self:drawRegularPopup(ctx)
    end
    
    -- Check if picker was just closed
    local just_closed = was_open and not self.is_open
    local should_clear_selection = just_closed and should_clear
    
    return changes_made, should_clear_selection
end

-- ============================================================================
-- MODAL POPUP (RECOMMENDED)
-- ============================================================================

-- Draw as modal popup (blocks other UI)
-- @param ctx (ImGui_Context)
-- @return (boolean) - True if changes made
--
-- MODAL BEHAVIOR:
-- - Dims background
-- - Blocks clicks outside popup
-- - Can be closed with ESC
-- - Professional feel

function CollectionPicker:drawModalPopup(ctx)
    local changes_made = false
    
    -- Try to begin modal popup
    local visible, open = reaper.ImGui_BeginPopupModal(
        ctx, 
        self.popup_id, 
        true,  -- Show close button
        reaper.ImGui_WindowFlags_AlwaysAutoResize()
    )
    
    if not visible then
        return false
    end
    
    -- Check if user closed popup
    if not open then
        self:close()
        reaper.ImGui_EndPopup(ctx)
        return false
    end
    
    -- HEADER
    if self.current_item then
        reaper.ImGui_Text(ctx, "Add to Collections:")
        reaper.ImGui_TextColored(ctx, 0xFF888888, self.current_item:getDisplayName())
        reaper.ImGui_Separator(ctx)
    end
    
    if self.is_bulk then
        reaper.ImGui_Text(ctx, "Add to Collections:")
        reaper.ImGui_Text(ctx, #self.current_items .. " items selected")
    end

    -- COLLECTION LIST (scrollable area)
    local list_height = 300
    if reaper.ImGui_BeginChild(ctx, "CollectionList", 400, list_height, reaper.ImGui_ChildFlags_Borders()) then
        
        if self.show_hierarchy then
            changes_made = self:drawHierarchicalList(ctx) or changes_made
        else
            changes_made = self:drawFlatList(ctx) or changes_made
        end
        
        reaper.ImGui_EndChild(ctx)
    end
    
    reaper.ImGui_Separator(ctx)
    
    -- FOOTER BUTTONS
    changes_made = self:drawFooterButtons(ctx) or changes_made

    reaper.ImGui_EndPopup(ctx)
    
    return changes_made
end

-- ============================================================================
-- REGULAR POPUP (ALTERNATIVE)
-- ============================================================================

-- Draw as regular popup (non-blocking)
-- @param ctx (ImGui_Context)
-- @return (boolean) - True if changes made
--
-- REGULAR POPUP BEHAVIOR:
-- - No dimmed background
-- - Can click outside to close
-- - Lighter weight
-- - Good for quick actions

function CollectionPicker:drawRegularPopup(ctx)
    local changes_made = false
    
    if not reaper.ImGui_BeginPopup(ctx, self.popup_id) then
        return false
    end
    
    -- Same content as modal
    if self.current_item then
        reaper.ImGui_Text(ctx, "Add to Collections:")
        reaper.ImGui_Text(ctx, self.current_item:getDisplayName())
        reaper.ImGui_Separator(ctx)
    end
    
    if reaper.ImGui_BeginChild(ctx, "CollectionList", 300, 200, reaper.ImGui_ChildFlags_Borders()) then
        if self.show_hierarchy then
            changes_made = self:drawHierarchicalList(ctx) or changes_made
        else
            changes_made = self:drawFlatList(ctx) or changes_made
        end
        reaper.ImGui_EndChild(ctx)
    end
    
    reaper.ImGui_Separator(ctx)
    changes_made = self:drawFooterButtons(ctx) or changes_made
    
    reaper.ImGui_EndPopup(ctx)
    
    return changes_made
end

-- ============================================================================
-- COLLECTION LIST RENDERING
-- ============================================================================

-- Draw collections in hierarchical tree format
-- @param ctx (ImGui_Context)
-- @return (boolean) - True if changes made
--
-- VISUAL:
--   ✓ SFX
--     ✓ Footsteps
--       □ Indoor
--     ✓ Impacts

function CollectionPicker:drawHierarchicalList(ctx)
    -- Support both single item and bulk mode
    if not self.current_item and not self.is_bulk then return false end
    
    local changes_made = false
    
    -- Get root collections
    local roots = self.manager:getRootCollections()
    
    for _, root in ipairs(roots) do
        -- Skip "All Items" virtual collection
        if root.id ~= "ALL_ITEMS" then
            local changed = self:drawCollectionCheckbox(ctx, root, 0)
            changes_made = changes_made or changed
        end
    end
    
    return changes_made
end

-- Draw collections in flat list format
-- @param ctx (ImGui_Context)
-- @return (boolean) - True if changes made
--
-- VISUAL:
--   ✓ SFX
--   ✓ Footsteps
--   □ Indoor
--   ✓ Impacts
--
-- WHEN TO USE: Simpler, easier to scan for many collections

function CollectionPicker:drawFlatList(ctx)
    -- Support both single item and bulk mode
    if not self.current_item and not self.is_bulk then return false end
    
    local changes_made = false
    
    -- Get all collections (except All Items)
    local all_collections = self.manager:getAllCollections()
    
    for _, collection in ipairs(all_collections) do
        if collection.id ~= "ALL_ITEMS" then
            -- Show full path for context in flat list
            local display_text = collection:getDisplayName()
            
            -- Add path if not root
            if not collection:isRoot() then
                local full_path = collection:getFullPath(all_collections)
                display_text = display_text .. " (" .. full_path .. ")"
            end
            
            -- Determine checkbox state (bulk or single mode)
            local is_checked = false
            local is_mixed = false
            
            if self.is_bulk then
                -- Count how many items are in this collection
                local count_in = 0
                for _, item in ipairs(self.current_items) do
                    if item:isInCollection(collection.id) then
                        count_in = count_in + 1
                    end
                end
                is_checked = count_in == #self.current_items
                is_mixed = count_in > 0 and count_in < #self.current_items
            else
                -- Single item mode
                is_checked = self.current_item:isInCollection(collection.id)
            end
            
            -- Draw checkbox (with mixed state styling if applicable)
            if is_mixed then
                reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 0xFF808080)
            end
            
            local changed, new_value = reaper.ImGui_Checkbox(
                ctx, 
                display_text .. "##" .. collection.id, 
                is_checked
            )
            
            if is_mixed then
                reaper.ImGui_PopStyleColor(ctx)
            end
            
            if changed then
                if self.is_bulk then
                    -- Apply to all items in bulk selection
                    for _, item in ipairs(self.current_items) do
                        if new_value then
                            item:addToCollection(collection.id)
                        else
                            item:removeFromCollection(collection.id)
                        end
                    end
                else
                    -- Single item mode
                    if new_value then
                        self.current_item:addToCollection(collection.id)
                    else
                        self.current_item:removeFromCollection(collection.id)
                    end
                end
                changes_made = true
            end
        end
    end
    
    return changes_made
end

-- Draw a single collection checkbox (recursive for hierarchy)
-- @param ctx (ImGui_Context)
-- @param collection (Collection) - Collection to draw
-- @param depth (number) - Indentation depth
-- @return (boolean) - True if changes made

function CollectionPicker:drawCollectionCheckbox(ctx, collection, depth)
    -- Support both single item and bulk mode
    if not self.current_item and not self.is_bulk then return false end
    
    local changes_made = false
    
    -- INDENTATION (for hierarchy)
    if depth > 0 then
        reaper.ImGui_Indent(ctx, 20)
    end
    
    -- CHECK IF ITEM(S) ARE IN THIS COLLECTION
    local is_checked = false
    local is_mixed = false
    
    if self.is_bulk then
        -- Count how many items are in this collection
        local count_in = 0
        for _, item in ipairs(self.current_items) do
            if item:isInCollection(collection.id) then
                count_in = count_in + 1
            end
        end
        is_checked = count_in == #self.current_items
        is_mixed = count_in > 0 and count_in < #self.current_items
    else
        -- Single item mode
        is_checked = self.current_item:isInCollection(collection.id)
    end
    
    -- DRAW CHECKBOX (with mixed state styling if applicable)
    local display_text = collection:getDisplayName()
    
    if is_mixed then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 0xFF808080)
    end
    
    local changed, new_value = reaper.ImGui_Checkbox(
        ctx, 
        display_text .. "##" .. collection.id, 
        is_checked
    )
    
    if is_mixed then
        reaper.ImGui_PopStyleColor(ctx)
    end
    
    if changed then
        if self.is_bulk then
            -- Apply to all items in bulk selection
            for _, item in ipairs(self.current_items) do
                if new_value then
                    item:addToCollection(collection.id)
                else
                    item:removeFromCollection(collection.id)
                end
            end
        else
            -- Single item mode
            if new_value then
                self.current_item:addToCollection(collection.id)
            else
                self.current_item:removeFromCollection(collection.id)
            end
        end
        changes_made = true
    end
    
    -- DRAW CHILDREN (recursively)
    local children = self.manager:getChildCollections(collection.id)
    for _, child in ipairs(children) do
        local child_changed = self:drawCollectionCheckbox(ctx, child, depth + 1)
        changes_made = changes_made or child_changed
    end
    
    -- UNINDENT
    if depth > 0 then
        reaper.ImGui_Unindent(ctx, 20)
    end
    
    return changes_made
end

-- ============================================================================
-- FOOTER BUTTONS (with inline new collection input)
-- ============================================================================

-- Draw footer buttons with inline new collection input
-- @param ctx (ImGui_Context)
-- @return (boolean) - True if changes made
--
-- SOLUTION D: Inline Input (no nested popup)
-- Shows input field directly in the footer when user wants to create collection

function CollectionPicker:drawFooterButtons(ctx)
    local changes_made = false
    
    -- TWO STATES: Normal buttons OR inline input
    
    if not self.inline_new_collection then
        -- ====================================================================
        -- STATE 1: NORMAL BUTTONS
        -- ====================================================================
        
        -- NEW COLLECTION BUTTON
        if self.allow_new_collection then
            if reaper.ImGui_Button(ctx, "+ New Collection...", 150, 0) then
                self.inline_new_collection = true
                self.new_collection_name = ""  -- Reset
            end
            
            reaper.ImGui_SameLine(ctx)
        end
        
        -- AUTO-DESELECT CHECKBOX (only show in bulk mode)
        if self.is_bulk then
            local changed, new_value = reaper.ImGui_Checkbox(
                ctx, 
                "Clear selection", 
                self.clear_selection_on_close
            )
            if changed then
                self.clear_selection_on_close = new_value
            end
            
            -- Tooltip
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx, "Clear multi-selection after closing")
            end
            
            reaper.ImGui_SameLine(ctx)
        end
        
        -- CLOSE BUTTON
        if reaper.ImGui_Button(ctx, "Done", 150, 0) then
            self:close()
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        
    else
        -- ====================================================================
        -- STATE 2: INLINE NEW COLLECTION INPUT
        -- ====================================================================
        
        reaper.ImGui_Text(ctx, "New collection:")
        
        -- Auto-focus input on first frame
        if reaper.ImGui_IsWindowAppearing(ctx) or self.new_collection_name == "" then
            reaper.ImGui_SetKeyboardFocusHere(ctx)
        end
        
        reaper.ImGui_SetNextItemWidth(ctx, 200)
        local changed, name = reaper.ImGui_InputText(ctx, "##newcollection", self.new_collection_name)
        if changed then
            self.new_collection_name = name
        end
        
        reaper.ImGui_SameLine(ctx)
        
        -- ADD BUTTON (or press Enter)
        if reaper.ImGui_Button(ctx, "Add", 60, 0) or 
           (reaper.ImGui_IsItemDeactivated(ctx) and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter())) then
            
            if self.new_collection_name ~= "" then
                -- Create collection
                local collection, err = self.manager:createCollection(self.new_collection_name)
                
                if collection then
                    -- Add current item to new collection
                    if self.current_item then
                        self.current_item:addToCollection(collection.id)
                        changes_made = true
                    end
                    
                    -- Reset state
                    self.inline_new_collection = false
                    self.new_collection_name = ""
                else
                    -- Show error
                    reaper.ShowMessageBox(err or "Could not create collection", "Error", 0)
                end
            end
        end
        
        reaper.ImGui_SameLine(ctx)
        
        -- CANCEL BUTTON (or press Escape)
        if reaper.ImGui_Button(ctx, "Cancel", 60, 0) or 
           reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
            self.inline_new_collection = false
            self.new_collection_name = ""
        end
    end
    
    return changes_made
end

-- ============================================================================
-- UTILITY METHODS
-- ============================================================================

-- Set whether to show hierarchy
-- @param show (boolean)
function CollectionPicker:setShowHierarchy(show)
    self.show_hierarchy = show
end

-- Set whether to allow creating new collections
-- @param allow (boolean)
function CollectionPicker:setAllowNewCollection(allow)
    self.allow_new_collection = allow
end

-- Check if any changes were made (for save detection)
-- Note: This is tracked by the return value of draw()
-- This method exists for API completeness
function CollectionPicker:hasChanges()
    -- Changes are returned by draw() immediately
    -- No need to track separately
    return false
end

function CollectionPicker:openBulk(items)
    self.current_items = items
    self.is_bulk = true
    self.is_open = true
end

return CollectionPicker