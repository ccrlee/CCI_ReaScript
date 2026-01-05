-- CollectionManager.lua
-- Central manager for all collections in Source Explorer

local CollectionManager = {}
CollectionManager.__index = CollectionManager

-- Load Dependencies
local script_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"
local Collection = require("Collection")

function CollectionManager.new()
    local self = setmetatable({}, CollectionManager)

    -- CORE DATA STRUCTURE
    self.collections = {}
    
    -- STATE MANAGEMENT
    self.current_collection_id = nil
    
    -- INITIALIZE WITH DEFAULT COLLECTIONS
    -- 1. All Items (virtual collection)
    local all_items = Collection.new({
        id = "ALL_ITEMS",
        name = "All Items",
        parent_id = nil,
        color = 0xFFCCCCCC,
        icon = "📦"
    })
    table.insert(self.collections, all_items)
    
    -- 2. Favorites (auto-sync with favorite checkbox)
    local favorites = Collection.new({
        id = "FAVORITES",
        name = "Favorites",
        parent_id = nil,
        color = 0xFFFFD700,  -- Gold color
        icon = "⭐"
    })
    table.insert(self.collections, favorites)
    
    return self
end

-- ============================================================================
-- CRUD OPERATIONS (Create, Read, Update, Delete)
-- ============================================================================

-- CREATE: Add a new collection
-- @param name (string) - Display name
-- @param parent_id (string, optional) - ID of parent collection
-- @param color (number, optional) - Color in AABBGGRR format
-- @param icon (string, optional) - Emoji or text icon
-- @return (Collection, string) - New collection object and error message if any
--
-- VALIDATION:
-- - Ensures parent exists (if specified)
-- - Prevents circular references
-- - Checks for duplicate names at same level (optional)

function CollectionManager:createCollection(name, parent_id, color, icon)
    -- Validate name
    if not name or name == "" then
        return nil, "Collection name cannot be empty"
    end

    -- Validate parent exists (if specified)
    if parent_id then
        local parent = self:getCollection(parent_id)
        if not parent then
            return nil, "Parent collection not found"
        end
    end

    -- Create new collection
    local collection = Collection.new({
        name = name,
        parent_id = parent_id,
        color = color,
        icon = icon,
    })

    -- Validate hierarchy (prevent circular references)
    local can_be_child, error_msg = collection:canBeChildOf(parent_id, self.collections)
    if not can_be_child then
        return nil, error_msg
    end

    table.insert(self.collections, collection)
    
    return collection, "OK"
end

-- READ: Get collection by ID
-- @param collection_id (string) - The ID to find
-- @return (Collection or nil) - The collection object if found
--
function CollectionManager:getCollection(collection_id)
    if not collection_id then return nil end

    for _, col in ipairs(self.collections) do
        if col.id == collection_id then
            return col
        end
    end

    return nil
end


-- UPDATE: Rename a collection
-- @param collection_id (string) - ID of collection to rename
-- @param new_name (string) - New name
-- @return (boolean, string) - Success and error message if any

function CollectionManager:renameCollection(collection_id, new_name)
    -- Validate inputs
    if not new_name or new_name == "" then
        return false, "Name cannot be empty"
    end
    
    -- Special collections can't be renamed
    if collection_id == "ALL_ITEMS" or collection_id == "FAVORITES" then
        return false, "Cannot rename system collections"
    end
    
    -- Find collection
    local collection = self:getCollection(collection_id)
    if not collection then
        return false, "Collection not found"
    end
    
    -- Rename
    collection.name = new_name
    
    return true, "OK"
end

-- DELETE: Remove a collection
-- @param collection_id (string) - ID of collection to delete
-- @param delete_children (boolean, optional) - If true, also delete child collections
-- @return (boolean, string) - Success and error message if any
--
-- IMPORTANT BEHAVIOR:
-- - If delete_children = true: Deletes collection and all descendants
-- - If delete_children = false: Only deletes if no children exist
-- - Special collections (ALL_ITEMS) cannot be deleted
-- - DOES NOT delete the audio items themselves (they just lose this tag)

function CollectionManager:deleteCollection(collection_id, delete_children)
    -- Can't delete special collections
    if collection_id == "ALL_ITEMS" or collection_id == "FAVORITES" then
        return false, "Cannot delete system collections"
    end
    
    -- Find collection
    local collection = self:getCollection(collection_id)
    if not collection then
        return false, "Collection not found"
    end
    
    -- Check for children
    local children = self:getChildCollections(collection_id)
    
    if #children > 0 and not delete_children then
        return false, string.format("Collection has %d child collections. Delete children first or use delete_children=true", #children)
    end
    
    -- Delete children recursively if requested
    if delete_children then
        for _, child in ipairs(children) do
            self:deleteCollection(child.id, true)  -- Recursive
        end
    end
    
    -- Find and remove from array
    for i, col in ipairs(self.collections) do
        if col.id == collection_id then
            table.remove(self.collections, i)
            
            -- If we're deleting the current collection, reset to "All Items"
            if self.current_collection_id == collection_id then
                self.current_collection_id = nil
            end
            
            return true, "OK"
        end
    end
    
    return false, "Collection not found in array"
end

-- ============================================================================
-- HIERARCHY NAVIGATION
-- ============================================================================

-- Get all root-level collections
-- @return (table) - Array of Collection objects with no parent
--
-- USE CASE: Drawing the top level of the tree view

function CollectionManager:getRootCollections()
    local roots = {}
    
    for _, col in ipairs(self.collections) do
        if col:isRoot() then
            table.insert(roots, col)
        end
    end
    
    return roots
end

-- Get all child collections of a parent
-- @param parent_id (string) - ID of parent collection
-- @return (table) - Array of Collection objects that are children
--
-- USE CASE: Drawing children when user expands a tree node

function CollectionManager:getChildCollections(parent_id)
    local children = {}
    
    for _, col in ipairs(self.collections) do
        if col.parent_id == parent_id then
            table.insert(children, col)
        end
    end
    
    return children
end

-- Get parent collection of a collection
-- @param collection_id (string) - ID of collection
-- @return (Collection or nil) - Parent collection if it has one
--
-- USE CASE: Breadcrumb navigation, "go to parent" button

function CollectionManager:getParentCollection(collection_id)
    local collection = self:getCollection(collection_id)
    if not collection or not collection.parent_id then
        return nil
    end
    
    return self:getCollection(collection.parent_id)
end

-- Get all ancestor collections (parent, grandparent, etc.)
-- @param collection_id (string) - ID of collection
-- @return (table) - Array of Collection objects from immediate parent to root
--
-- USE CASE: Breadcrumb trail: "SFX / Footsteps / Indoor"

function CollectionManager:getAncestors(collection_id)
    local ancestors = {}
    local current = self:getCollection(collection_id)
    
    while current and current.parent_id do
        local parent = self:getParentCollection(current.id)
        if parent then
            table.insert(ancestors, parent)
            current = parent
        else
            break
        end
    end
    
    return ancestors
end

-- Get count of all descendants (children, grandchildren, etc.)
-- @param collection_id (string) - ID of collection
-- @return (number) - Total number of descendants
--
-- USE CASE: "Delete collection and 15 descendants" warning

function CollectionManager:getDescendantCount(collection_id)
    local children = self:getChildCollections(collection_id)
    local count = #children
    
    -- Recursively count grandchildren
    for _, child in ipairs(children) do
        count = count + self:getDescendantCount(child.id)
    end
    
    return count
end

-- ============================================================================
-- ITEM FILTERING
-- ============================================================================

-- Filter items based on current collection
-- @param items (table) - Array of AudioItem objects
-- @return (table) - Filtered array of AudioItem objects
--
-- BEHAVIOR:
-- - If current_collection_id is nil: Returns all items (show everything)
-- - Otherwise: Returns only items that are in current collection
--
-- USE CASE: Main filtering for the item table display

function CollectionManager:filterItemsByCollection(items)
    -- If no collection selected, show all
    if self.current_collection_id == nil then
        return items
    end
    
    -- Special case: "All Items" shows everything
    if self.current_collection_id == "ALL_ITEMS" then
        return items
    end
    
    -- Filter items
    local filtered = {}
    
    for _, item in ipairs(items) do
        if item:isInCollection(self.current_collection_id) then
            table.insert(filtered, item)
        end
    end
    
    return filtered
end

-- Filter items by multiple collections (OR logic)
-- @param items (table) - Array of AudioItem objects
-- @param collection_ids (table) - Array of collection IDs to check
-- @return (table) - Items in ANY of the specified collections
--
-- USE CASE: "Show items in SFX OR Impacts OR Footsteps"

function CollectionManager:filterItemsByAnyCollection(items, collection_ids)
    if not collection_ids or #collection_ids == 0 then
        return items
    end
    
    local filtered = {}
    
    for _, item in ipairs(items) do
        if item:isInAnyCollection(collection_ids) then
            table.insert(filtered, item)
        end
    end
    
    return filtered
end

-- Get item count for a specific collection
-- @param collection_id (string) - ID of collection
-- @param items (table) - Array of all AudioItem objects
-- @return (number) - Count of items in this collection
--
-- USE CASE: Display "SFX (45)" in sidebar

function CollectionManager:getCollectionItemCount(collection_id, items)
    -- All Items shows total
    if not collection_id or collection_id == "ALL_ITEMS" then
        return #items
    end
    
    local count = 0
    for _, item in ipairs(items) do
        if item:isInCollection(collection_id) then
            count = count + 1
        end
    end
    
    return count
end

-- ============================================================================
-- CURRENT COLLECTION STATE
-- ============================================================================

-- Set the current viewing collection
-- @param collection_id (string or nil) - ID to set as current (nil = "All Items")
-- @return (boolean) - True if set successfully

function CollectionManager:setCurrentCollection(collection_id)
    -- nil is valid (means "All Items")
    if collection_id == nil then
        self.current_collection_id = nil
        return true
    end
    
    -- Validate collection exists
    local collection = self:getCollection(collection_id)
    if not collection then
        return false
    end
    
    self.current_collection_id = collection_id
    return true
end

-- Get current collection ID
-- @return (string or nil) - Current collection ID (nil = "All Items")

function CollectionManager:getCurrentCollectionId()
    return self.current_collection_id
end

-- Get current collection object
-- @return (Collection or nil) - Current collection object

function CollectionManager:getCurrentCollection()
    if self.current_collection_id == nil then
        return nil
    end
    
    return self:getCollection(self.current_collection_id)
end

-- Check if viewing "All Items"
-- @return (boolean) - True if no specific collection selected

function CollectionManager:isShowingAllItems()
    return self.current_collection_id == nil or self.current_collection_id == "ALL_ITEMS"
end

-- ============================================================================
-- BATCH OPERATIONS
-- ============================================================================

-- Get all collection IDs (flat list)
-- @return (table) - Array of all collection IDs
--
-- USE CASE: Dropdown menu, iteration, validation

function CollectionManager:getAllCollectionIds()
    local ids = {}
    for _, col in ipairs(self.collections) do
        table.insert(ids, col.id)
    end
    return ids
end

-- Get all collections (flat list)
-- @return (table) - Array of all Collection objects

function CollectionManager:getAllCollections()
    return self.collections
end

-- Get collection count
-- @return (number) - Total number of collections

function CollectionManager:getCollectionCount()
    return #self.collections
end

-- Search collections by name
-- @param search_term (string) - Text to search for
-- @return (table) - Array of Collection objects matching search
--
-- USE CASE: Collection search/filter in sidebar

function CollectionManager:searchCollections(search_term)
    local results = {}
    
    for _, col in ipairs(self.collections) do
        if col:matchesSearch(search_term) then
            table.insert(results, col)
        end
    end
    
    return results
end

-- ============================================================================
-- DATA CLEANUP
-- ============================================================================

-- Remove a collection ID from all items
-- @param collection_id (string) - ID to remove
-- @param items (table) - Array of AudioItem objects
-- @return (number) - Count of items affected
--
-- USE CASE: When deleting a collection, clean up item memberships

function CollectionManager:removeCollectionFromAllItems(collection_id, items)
    local count = 0
    
    for _, item in ipairs(items) do
        if item:removeFromCollection(collection_id) then
            count = count + 1
        end
    end
    
    return count
end

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

-- Convert all collections to plain tables for saving
-- @return (table) - Array of plain tables
--
-- FORMAT:
-- {
--   { id = "001", name = "SFX", parent_id = nil, ... },
--   { id = "002", name = "Footsteps", parent_id = "001", ... },
--   ...
-- }

function CollectionManager:toTable()
    local tables = {}
    
    -- Only save user-created collections, NOT system collections
    for _, col in ipairs(self.collections) do
        if col.id ~= "ALL_ITEMS" and col.id ~= "FAVORITES" then
            table.insert(tables, col:toTable())
        end
    end
    
    return tables
end

-- Load collections from plain tables (after loading from file)
-- @param tables (table) - Array of plain tables
--
-- IMPORTANT: Clears existing collections first!

function CollectionManager:fromTable(tables)
    if not tables then return end
    
    -- SAVE system collections before clearing
    local system_collections = {}
    for _, col in ipairs(self.collections) do
        if col.id == "ALL_ITEMS" or col.id == "FAVORITES" then
            table.insert(system_collections, col)
        end
    end

    -- Clear existing
    self.collections = {}
    
    -- ADD system collections back FIRST
    for _, col in ipairs(system_collections) do
        table.insert(self.collections, col)
    end

    -- Load user collections from saved data
    for _, tbl in ipairs(tables) do
        local col = Collection.fromTable(tbl)
        if col then
            -- Skip system collections (already added above)
            if col.id ~= "ALL_ITEMS" and col.id ~= "FAVORITES" then
                table.insert(self.collections, col)
            end
        end
    end
    
    -- Reset current collection if it no longer exists
    if self.current_collection_id then
        if not self:getCollection(self.current_collection_id) then
            self.current_collection_id = nil
        end
    end
end

-- Create a CollectionManager from saved data (static constructor)
-- @param data (table) - Saved collection data
-- @return (CollectionManager) - New manager with loaded data

function CollectionManager.loadFromTable(data)
    local manager = CollectionManager.new()
    
    if data then
        manager:fromTable(data)
    end
    
    return manager
end

-- ============================================================================
-- VALIDATION & DEBUGGING
-- ============================================================================

-- Validate entire collection structure
-- @return (boolean, table) - Valid flag and array of error messages
--
-- CHECKS:
-- - No duplicate IDs
-- - All parent_ids reference existing collections
-- - No circular references
-- - No orphaned collections (parent deleted but child remains)

function CollectionManager:validate()
    local errors = {}
    local seen_ids = {}
    
    -- Check for duplicate IDs
    for _, col in ipairs(self.collections) do
        if seen_ids[col.id] then
            table.insert(errors, "Duplicate ID: " .. col.id)
        else
            seen_ids[col.id] = true
        end
    end
    
    -- Check parent references
    for _, col in ipairs(self.collections) do
        if col.parent_id then
            if not seen_ids[col.parent_id] then
                table.insert(errors, string.format("Collection '%s' has invalid parent_id: %s", col.name, col.parent_id))
            end
        end
    end
    
    -- Check for circular references
    for _, col in ipairs(self.collections) do
        local visited = {}
        local current = col
        
        while current and current.parent_id do
            if visited[current.id] then
                table.insert(errors, string.format("Circular reference detected involving: %s", current.name))
                break
            end
            
            visited[current.id] = true
            current = self:getCollection(current.parent_id)
        end
    end
    
    return #errors == 0, errors
end

-- Get debug string of entire structure
-- @return (string) - Human-readable tree structure

function CollectionManager:toDebugString()
    local lines = {}
    table.insert(lines, "=== Collection Structure ===")
    
    -- Show roots and their children recursively
    local function printNode(collection, indent)
        local prefix = string.rep("  ", indent)
        local info = string.format("%s%s (ID: %s)", prefix, collection:getDisplayName(), collection.id)
        table.insert(lines, info)
        
        local children = self:getChildCollections(collection.id)
        for _, child in ipairs(children) do
            printNode(child, indent + 1)
        end
    end
    
    local roots = self:getRootCollections()
    for _, root in ipairs(roots) do
        printNode(root, 0)
    end
    
    table.insert(lines, string.format("\nTotal: %d collections", #self.collections))
    table.insert(lines, string.format("Current: %s", self.current_collection_id or "All Items"))
    
    return table.concat(lines, "\n")
end

return CollectionManager