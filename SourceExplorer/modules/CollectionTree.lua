-- CollectionTree.lua
-- Tree view UI component for displaying and interacting with collections
--
-- RESPONSIBILITIES:
-- 1. Display collections in hierarchical tree
-- 2. Handle expand/collapse of nodes
-- 3. Handle selection (clicking)
-- 4. Show icons and visual styling
-- 5. Context menu on right-click
-- 6. Drag indicators (future)
--
-- DESIGN: Stateless Component
-- - Doesn't own the data (CollectionManager does)
-- - Just renders what it's told
-- - Reports interactions via callbacks or return values

local CollectionTree = {}
CollectionTree.__index = CollectionTree

-- Load ColorUtils for RGB-based colors
local script_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"
local ColorUtils = require("ColorUtils")

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

-- Create a new CollectionTree component
-- @param collection_manager (CollectionManager) - The manager to work with
-- @param options (table, optional) - Configuration options
--   - show_item_counts (boolean) - Show "(5)" next to collection names
--   - show_all_items (boolean) - Show "All Items" option at top
--   - allow_reorder (boolean) - Allow drag-drop reordering (future)
--
-- DESIGN DECISION: Pass manager reference
-- Why not just pass collections array? Because we need:
-- - getChildCollections() method
-- - setCurrentCollection() method
-- - Real-time updates when manager changes

function CollectionTree.new(collection_manager, options)
    options = options or {}
    
    local self = setmetatable({}, CollectionTree)
    
    -- REFERENCE TO DATA SOURCE
    self.manager = collection_manager
    
    -- UI OPTIONS
    self.show_item_counts = options.show_item_counts ~= false  -- Default true
    self.show_all_items = options.show_all_items ~= false      -- Default true
    self.allow_reorder = options.allow_reorder or false        -- Default false (future)
    
    -- STATE (what's currently selected in the tree)
    -- Note: This is UI state, different from manager.current_collection_id
    -- selected_id = what row is highlighted
    -- current_collection_id = what we're filtering by
    -- They're usually the same but can differ
    self.selected_id = nil
    self.collections_changed = false

    -- CONTEXT MENU STATE
    self.context_menu_collection_id = nil  -- Which collection was right-clicked
    self.context_menu_is_open = false
    self.is_submenu_open = false

    -- CALLBACKS
    self.on_collection_clicked = options.on_collection_clicked
    self.on_items_dropped = options.on_items_dropped  -- NEW!

    return self
end

-- ============================================================================
-- MAIN DRAWING METHOD
-- ============================================================================

-- Draw the complete collection tree
-- @param ctx (ImGui_Context) - ImGui context
-- @param width (number) - Width of tree area
-- @param height (number) - Height of tree area
-- @param items (table, optional) - Array of items for showing counts
-- @return (string or nil) - ID of clicked collection (if any)
--
-- USAGE:
--   local clicked_id = tree:draw(ctx, 200, 400, all_items)
--   if clicked_id then
--       -- User clicked a collection
--   end

function CollectionTree:draw(ctx, width, height, items)
    items = items or {}
    local clicked_collection_id = nil
    self.collections_changed = false
    
    -- BEGIN CHILD WINDOW
    -- This creates a scrollable area with border
    if not reaper.ImGui_BeginChild(ctx, 'CollectionTree', width, height, reaper.ImGui_ChildFlags_Borders()) then
        return nil
    end
    
    -- HEADER (optional "All Items" option)
    if self.show_all_items then
        clicked_collection_id = self:drawAllItemsRow(ctx, items)
        reaper.ImGui_Separator(ctx)
    end
    
    -- Show Favorites collection (similar to All Items)
    local favorites = self.manager:getCollection("FAVORITES")
    if favorites then
        clicked_collection_id = self:drawFavoritesRow(ctx, items) or clicked_collection_id
        reaper.ImGui_Separator(ctx)
    end

    -- TREE BODY
    -- Get root collections and draw them (which recursively draws children)
    local roots = self.manager:getRootCollections()
    
    for _, root in ipairs(roots) do
        -- Skip system collections (shown in header)
        if root.id ~= "ALL_ITEMS" and root.id ~= "FAVORITES" then
            local clicked = self:drawCollectionNode(ctx, root, items, 0)
            if clicked then
                clicked_collection_id = clicked
            end
        end
    end
        
    reaper.ImGui_EndChild(ctx)

    self:drawContextMenu(ctx)

    return clicked_collection_id, self.collections_changed
end

-- ============================================================================
-- ALL ITEMS ROW (SPECIAL CASE)
-- ============================================================================

-- Draw the "All Items" row at the top
-- @param ctx (ImGui_Context)
-- @param items (table) - All items for count
-- @return (string or nil) - "ALL_ITEMS" if clicked
--
-- WHY SPECIAL CASE?
-- "All Items" isn't really a collection, it's a UI concept
-- We handle it separately from the tree

function CollectionTree:drawAllItemsRow(ctx, items)
    local is_selected = self.manager:isShowingAllItems()
    
    -- Build display text
    local display_text = "📦 All Items"
    
    if self.show_item_counts then
        local count = #items
        display_text = display_text .. string.format(" (%d)", count)
    end
    
    -- SELECTABLE
    -- This is a clickable row that can be highlighted
    local clicked = reaper.ImGui_Selectable(ctx, display_text, is_selected)
    
    if clicked then
        self.selected_id = nil
        self.manager:setCurrentCollection(nil)
        return "ALL_ITEMS"
    end
    
    return nil
end

function CollectionTree:drawFavoritesRow(ctx, items)
    local is_selected = self.manager.current_collection_id == "FAVORITES"
    
    local display_text = "⭐ Favorites"
    
    if self.show_item_counts then
        local count = self.manager:getCollectionItemCount("FAVORITES", items)
        display_text = display_text .. string.format(" (%d)", count)
    end
    
    local clicked = reaper.ImGui_Selectable(ctx, display_text, is_selected)
    
    if clicked then
        self.selected_id = "FAVORITES"
        self.manager:setCurrentCollection("FAVORITES")
        return "FAVORITES"
    end
    
    return nil
end
-- ============================================================================
-- TREE NODE DRAWING (RECURSIVE)
-- ============================================================================

-- Draw a single collection node (and recursively its children)
-- @param ctx (ImGui_Context)
-- @param collection (Collection) - The collection to draw
-- @param items (table) - All items for counts
-- @param depth (number) - How deep in the tree (for styling)
-- @return (string or nil) - ID of clicked collection
--
-- THIS IS THE HEART OF THE TREE VIEW
-- It calls itself recursively to draw the entire hierarchy

function CollectionTree:drawCollectionNode(ctx, collection, items, depth)
    local clicked_collection_id = nil
    
    -- GET CHILDREN
    local children = self.manager:getChildCollections(collection.id)
    local has_children = #children > 0

    -- BUILD DISPLAY TEXT
    local display_text = collection:getDisplayName()

    if self.show_item_counts then
        local count = self.manager:getCollectionItemCount(collection.id, items)
        display_text = display_text .. string.format(" (%d)", count)
    end
    
    -- CONFIGURE TREE NODE FLAGS
    local flags = 0
    
    -- Open on arrow click (not on label click)
    flags = flags | reaper.ImGui_TreeNodeFlags_OpenOnArrow()
    
    -- Open on double-click of label
    flags = flags | reaper.ImGui_TreeNodeFlags_OpenOnDoubleClick()
    
    -- If no children, show as leaf (no arrow)
    if not has_children then
        flags = flags | reaper.ImGui_TreeNodeFlags_Leaf()
    end
    
    -- If this collection is selected, highlight it
    if self.selected_id == collection.id then
        flags = flags | reaper.ImGui_TreeNodeFlags_Selected()
    end

    -- DRAW THE TREE NODE
    -- TreeNodeEx returns true if the node is expanded
    local node_open = reaper.ImGui_TreeNodeEx(ctx, collection.id, display_text, flags)
    
    -- NEW: Make it accept drops
    if reaper.ImGui_BeginDragDropTarget(ctx) then
        local rv, payload = reaper.ImGui_AcceptDragDropPayload(ctx, "AUDIO_ITEMS")
    
        -- CRITICAL: Only process if payload is a string (actual drop happened)
        if rv and type(payload) == "string" then
            -- Parse the indices: "1,2,3" -> {1, 2, 3}
            local indices = {}
            for index_str in string.gmatch(payload, "[^,]+") do
                table.insert(indices, tonumber(index_str))
            end
            
            -- Call callback with collection and items
            if self.on_items_dropped then
                self.on_items_dropped(collection, indices)
            end
        end
        reaper.ImGui_EndDragDropTarget(ctx)
    end

    -- Draw colored background tint (if collection has a color)
    if collection.color and collection.color ~= 0xFFFFFFFF then
        local min_x, min_y = reaper.ImGui_GetItemRectMin(ctx)
        local max_x, max_y = reaper.ImGui_GetItemRectMax(ctx)
        local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
        
        -- Create semi-transparent version of the color
        -- Extract RGB from AABBGGRR format and add 20% alpha
        local alpha = 0x33000000  -- ~20% opacity
        local rgb = collection.color & 0x00FFFFFF
        local tint_color = alpha | rgb
        
        -- Draw background rectangle
        reaper.ImGui_DrawList_AddRectFilled(
            draw_list,
            min_x, min_y,
            30, max_y,
            collection.color -- use collection color instead of tint
        )
    end

    -- HANDLE CLICK (but not if we clicked the arrow)
    if reaper.ImGui_IsItemClicked(ctx) and not reaper.ImGui_IsItemToggledOpen(ctx) then
        self.selected_id = collection.id
        self.manager:setCurrentCollection(collection.id)
        clicked_collection_id = collection.id
    end
    
    -- HANDLE RIGHT-CLICK (for context menu)
    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Right()) then
        self.context_menu_collection_id = collection.id
        self.context_menu_is_open = true
    end
    
    -- HANDLE TOOLTIP (show full path on hover)
    if reaper.ImGui_IsItemHovered(ctx) then
        local full_path = collection:getFullPath(self.manager:getAllCollections())
        reaper.ImGui_SetTooltip(ctx, full_path)
    end
    
    -- DRAW CHILDREN (if node is expanded)
    if node_open then
        if has_children then
            -- RECURSION HAPPENS HERE
            for _, child in ipairs(children) do
                local clicked = self:drawCollectionNode(ctx, child, items, depth + 1)
                if clicked then
                    clicked_collection_id = clicked
                end
            end
        end
        
        -- IMPORTANT: Must call TreePop() if TreeNodeEx() returned true
        reaper.ImGui_TreePop(ctx)
    end
    
    return clicked_collection_id
end

-- ============================================================================
-- CONTEXT MENU
-- ============================================================================

-- Draw context menu for right-clicked collection
-- @param ctx (ImGui_Context)
--
-- OPERATIONS:
-- - Rename collection
-- - Delete collection
-- - Create child collection
-- - Change color
-- - Change icon

function CollectionTree:drawContextMenu(ctx)
    if self.context_menu_is_open then
        reaper.ImGui_OpenPopup(ctx, "CollectionContextMenu")
    end

    if not reaper.ImGui_BeginPopup(ctx, "CollectionContextMenu") then
        self.context_menu_is_open = false
        return
    end
    
    local collection = self.manager:getCollection(self.context_menu_collection_id)

    if not collection then
        reaper.ImGui_EndPopup(ctx)
        self.context_menu_is_open = false
        return
    end

    self.is_submenu_open = false

    -- HEADER
    reaper.ImGui_Text(ctx, collection:getDisplayName())
    reaper.ImGui_Separator(ctx)
    
    -- RENAME OPTION
    if reaper.ImGui_Selectable(ctx, "Rename...") then
        -- Show rename dialog
        local retval, new_name = reaper.GetUserInputs(
            "Rename Collection", 
            1, 
            "New name:", 
            collection.name
        )
        
        if retval and new_name and new_name ~= "" then
            local success, msg = self.manager:renameCollection(collection.id, new_name)
            if success then
                self.collections_changed = true
            else
                reaper.ShowMessageBox(msg, "Rename Error", 0)
            end
        end
        
        self.context_menu_is_open = false
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
    
    -- DELETE OPTION
    if reaper.ImGui_Selectable(ctx, "Delete") then
        -- Check for children
        local children = self.manager:getChildCollections(collection.id)
        
        if #children > 0 then
            -- Ask user if they want to delete children too
            local result = reaper.ShowMessageBox(
                string.format(
                    "Delete collection '%s'?\n\n" ..
                    "This collection has %d child collection(s).\n\n" ..
                    "Delete children too?",
                    collection.name,
                    #children
                ),
                "Delete Collection",
                4  -- Yes/No buttons
            )
            
            if result == 6 then  -- Yes
                local success = self.manager:deleteCollection(collection.id, true)
                if success then
                    self.collections_changed = true
                end
            elseif result == 7 then  -- No
                -- Don't delete
            end
        else
            -- No children - still ask for confirmation
            local result = reaper.ShowMessageBox(
                string.format("Delete collection '%s'?\n\nThis action cannot be undone.", collection.name),
                "Delete Collection",
                4  -- Yes/No buttons
            )
            
            if result == 6 then  -- Yes
                local success = self.manager:deleteCollection(collection.id, false)
                if success then
                    self.collections_changed = true
                end
            end
            -- If No (result == 7), do nothing
        end
        
        self.context_menu_is_open = false
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
    
    reaper.ImGui_Separator(ctx)
    
    if reaper.ImGui_Selectable(ctx, "New Collection...") then
        local retval, new_col_name = reaper.GetUserInputs(
            'New COllection Name',
            1,
            "Name:",
            "New Collection"
        )

        if retval and new_col_name and new_col_name ~= "" then
            local new_collection, err = self.manager:createCollection(new_col_name, nil)
            if new_collection then
                self.collections_changed = true
            else
                reaper.ShowMessageBox(err or "Failed to create collection", "Error", 0)
            end
        end

        self.context_menu_is_open = false
        reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_Separator(ctx)
    -- CREATE CHILD OPTION
    if reaper.ImGui_Selectable(ctx, "New Child Collection...") then
        local retval, child_name = reaper.GetUserInputs(
            "New Child Collection", 
            1, 
            "Name:", 
            "New Collection"
        )
        
        if retval and child_name and child_name ~= "" then
            local new_collection, err = self.manager:createCollection(child_name, collection.id)
            if new_collection then
                self.collections_changed = true
            else
                reaper.ShowMessageBox(err or "Failed to create collection", "Error", 0)
            end
        end
        
        self.context_menu_is_open = false
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
    
    reaper.ImGui_Separator(ctx)
    
    -- APPEARANCE SUBMENU
    if reaper.ImGui_BeginMenu(ctx, "Appearance") then
        self.is_submenu_open = true
        -- COLOR OPTIONS
        if reaper.ImGui_BeginMenu(ctx, "Color") then
            -- Color palette
            local colors = {
                {name = "Blue",   color = ColorUtils.Palette.Blue},  -- RGB(107, 142, 201) - Nice blue
                {name = "Green",  color = ColorUtils.Palette.Green},  -- RGB(107, 201, 158) - Nice green
                {name = "Red",    color = ColorUtils.Palette.Red},  -- RGB(201, 107, 107) - Nice red
                {name = "Orange", color = ColorUtils.Palette.Orange},  -- RGB(201, 163, 107) - Nice orange
                {name = "Purple", color = ColorUtils.Palette.Purple},  -- RGB(176, 107, 201) - Nice purple
                {name = "Yellow", color = ColorUtils.Palette.Yellow},  -- RGB(201, 201, 107) - Nice yellow
                {name = "Cyan",   color = ColorUtils.Palette.Cyan},  -- RGB(107, 201, 201) - Nice cyan
                {name = "Pink",   color = ColorUtils.Palette.Pink},  -- RGB(201, 107, 176) - Nice pink
                {name = "Gray",   color = ColorUtils.Palette.Gray},  -- RGB(170, 170, 170) - Gray
                {name = "White",  color = ColorUtils.Palette.White},  -- RGB(255, 255, 255) - White
            }
            
            for _, color_option in ipairs(colors) do
                -- Show checkmark if this is the current color
                local is_current = collection.color == color_option.color
                
                -- Draw color preview box
                local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
                local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
                
                -- Draw small color rectangle
                reaper.ImGui_DrawList_AddRectFilled(
                    draw_list,
                    cursor_x + 2, cursor_y + 2,
                    cursor_x + 14, cursor_y + 14,
                    color_option.color
                )
                
                -- Add border
                reaper.ImGui_DrawList_AddRect(
                    draw_list,
                    cursor_x + 2, cursor_y + 2,
                    cursor_x + 14, cursor_y + 14,
                    0xFF000000
                )
                
                -- Move cursor to make room for color box
                reaper.ImGui_SetCursorPosX(ctx, reaper.ImGui_GetCursorPosX(ctx) + 20)
                
                -- Menu item
                if reaper.ImGui_MenuItem(ctx, color_option.name, nil, is_current) then
                    collection.color = color_option.color
                    self.collections_changed = true
                    self.context_menu_is_open = false
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
            end
            
            reaper.ImGui_EndMenu(ctx)
        end
        
        -- ICON OPTIONS
        if reaper.ImGui_BeginMenu(ctx, "Icon") then
            local icons = {
                {name = "Folder",     icon = "📁"},
                {name = "Speaker",    icon = "🔊"},
                {name = "Speech",     icon = "💬"},
                {name = "Music",      icon = "🎵"},
                {name = "Explosion",  icon = "💥"},
                {name = "Footsteps",  icon = "👟"},
                {name = "House",      icon = "🏠"},
                {name = "Tree",       icon = "🌲"},
                {name = "Fire",       icon = "🔥"},
                {name = "Water",      icon = "💧"},
                {name = "Wind",       icon = "💨"},
                {name = "Star",       icon = "⭐"},
                {name = "Diamond",    icon = "💎"},
                {name = "Package",    icon = "📦"},
            }
            
            for _, icon_option in ipairs(icons) do
                -- Show checkmark if this is the current icon
                local is_current = collection.icon == icon_option.icon
                local display_text = icon_option.icon .. " " .. icon_option.name
                
                if reaper.ImGui_MenuItem(ctx, display_text, nil, is_current) then
                    collection.icon = icon_option.icon
                    self.collections_changed = true
                    self.context_menu_is_open = false
                    reaper.ImGui_CloseCurrentPopup(ctx)
                end
            end
            
            reaper.ImGui_EndMenu(ctx)
        end
        
        reaper.ImGui_EndMenu(ctx)
    end
    
    -- Check if clicked outside
    if not reaper.ImGui_IsWindowHovered(ctx) and 
        reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and not self.is_submenu_open then
        self.context_menu_is_open = false
        reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_EndPopup(ctx)
end
-- ============================================================================
-- UTILITY METHODS
-- ============================================================================

-- Get currently selected collection ID
-- @return (string or nil) - Selected collection ID

function CollectionTree:getSelectedId()
    return self.selected_id
end

-- Set selected collection ID
-- @param collection_id (string or nil) - ID to select

function CollectionTree:setSelectedId(collection_id)
    self.selected_id = collection_id
end

-- Clear selection
function CollectionTree:clearSelection()
    self.selected_id = nil
end

-- Expand all nodes (by returning list of open nodes)
-- Note: ImGui doesn't provide direct "expand all" so this is a helper
-- The main script would need to track open nodes and use SetNextItemOpen

function CollectionTree:getAllCollectionIds()
    return self.manager:getAllCollectionIds()
end

-- ============================================================================
-- SEARCH/FILTER SUPPORT
-- ============================================================================

-- Draw filtered tree (only showing collections matching search)
-- @param ctx (ImGui_Context)
-- @param width (number)
-- @param height (number)
-- @param items (table)
-- @param search_term (string) - Search query
-- @return (string or nil) - Clicked collection ID

function CollectionTree:drawFiltered(ctx, width, height, items, search_term)
    if not search_term or search_term == "" then
        return self:draw(ctx, width, height, items)
    end
    
    items = items or {}
    local clicked_collection_id = nil
    
    if not reaper.ImGui_BeginChild(ctx, 'CollectionTreeFiltered', width, height, reaper.ImGui_ChildFlags_Borders()) then
        return nil
    end
    
    -- Show "All Items" if it matches
    if self.show_all_items then
        local all_items_text = "all items"
        if all_items_text:find(search_term:lower(), 1, true) then
            clicked_collection_id = self:drawAllItemsRow(ctx, items)
        end
    end
    
    -- Show matching collections (flat list, no hierarchy)
    local matching = self.manager:searchCollections(search_term)
    
    for _, collection in ipairs(matching) do
        if collection.id ~= "ALL_ITEMS" then
            local is_selected = self.selected_id == collection.id
            
            local display_text = collection:getDisplayName()
            
            if self.show_item_counts then
                local count = self.manager:getCollectionItemCount(collection.id, items)
                display_text = display_text .. string.format(" (%d)", count)
            end
            
            -- Show full path in filtered view (helpful for context)
            local full_path = collection:getFullPath(self.manager:getAllCollections())
            if full_path ~= collection.name then
                display_text = display_text .. " - " .. full_path
            end
            
            local clicked = reaper.ImGui_Selectable(ctx, display_text, is_selected)
            
            if clicked then
                self.selected_id = collection.id
                self.manager:setCurrentCollection(collection.id)
                clicked_collection_id = collection.id
            end
        end
    end
    
    reaper.ImGui_EndChild(ctx)
    
    return clicked_collection_id
end

return CollectionTree