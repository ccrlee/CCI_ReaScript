-- Collection.lua
-- Data model for individual collections/folders in Source Explorer

local Collection = {}
Collection.__index = Collection

function Collection.new(config)
    config = config or {}
    
    local self = setmetatable({}, Collection)

    self.id = config.id or (os.time() .. "_" .. math.random(1000, 9999))

    -- BASIC PROPERTIES
    self.name = config.name or "New Collection"
    self.parent_id = config.parent_id or nil  -- nil means "root level"

    self.color = config.color or 0xFFFFFFFF
    self.icon = config.icon or "📁"

    return self
end

function Collection:isRoot()
    return self.parent_id == nil
end

function Collection:getDepth(all_collections)
    if self:isRoot() then
        return 0
    end
    
    -- Find parent and recursively calculate depth
    for _, col in ipairs(all_collections) do
        if col.id == self.parent_id then
            return 1 + col:getDepth(all_collections)
        end
    end
    
    -- Parent not found? Treat as root
    return 0
end


function Collection:getDisplayName()
    return self.icon .. " " .. self.name
end

function Collection:getFullPath(all_collections)
    if self:isRoot() then
        return self.name
    end
    
    -- Find parent and recursively build path
    for _, col in ipairs(all_collections) do
        if col.id == self.parent_id then
            return col:getFullPath(all_collections) .. " / " .. self.name
        end
    end
    
    -- Parent not found? Just return name
    return self.name
end

function Collection:canBeChildOf(potential_parent_id, all_collections)
    -- Can always be a root collection
    if potential_parent_id == nil then
        return true, "OK"
    end
    
    -- Can't be child of itself
    if potential_parent_id == self.id then
        return false, "Cannot be a child of itself"
    end
    
    -- Check if potential parent is actually a descendant of this collection
    -- (would create circular reference)
    local parent = nil
    for _, col in ipairs(all_collections) do
        if col.id == potential_parent_id then
            parent = col
            break
        end
    end
    
    if not parent then
        return false, "Parent collection not found"
    end
    
    -- Walk up the parent's ancestry to check for circular reference
    local current = parent
    while current do
        if current.id == self.id then
            return false, "Would create circular reference"
        end
        
        -- Find current's parent
        if current.parent_id == nil then
            break  -- Reached root
        end
        
        local found_parent = false
        for _, col in ipairs(all_collections) do
            if col.id == current.parent_id then
                current = col
                found_parent = true
                break
            end
        end
        
        if not found_parent then
            break  -- Parent chain broken
        end
    end
    
    return true, "OK"
end

function Collection:toTable()
    return {
        id = self.id,
        name = self.name,
        parent_id = self.parent_id,
        color = self.color,
        icon = self.icon
    }
end

function Collection.fromTable(tbl)
    if not tbl then return nil end
    return Collection.new(tbl)
end

function Collection:clone()
    return Collection.new({
        id = self.id,  -- Usually you'd generate new ID for true clone
        name = self.name,
        parent_id = self.parent_id,
        color = self.color,
        icon = self.icon
    })
end

function Collection:matchesSearch(search_term)
    if not search_term or search_term == "" then
        return true
    end
    
    local search_lower = search_term:lower()
    local name_lower = self.name:lower()
    
    return name_lower:find(search_lower, 1, true) ~= nil
end


-- ============================================================================
-- DEBUGGING
-- ============================================================================

-- Get a string representation of this collection for debugging
-- @return (string) - Human-readable description

function Collection:toString()
    local parent_str = self.parent_id and ("parent: " .. self.parent_id) or "root"
    return string.format("Collection[%s]: '%s' (%s)", self.id, self.name, parent_str)
end

return Collection