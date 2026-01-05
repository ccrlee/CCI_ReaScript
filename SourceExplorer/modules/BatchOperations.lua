-- BatchOperations.lua
-- Coordinator module for all batch operations in Source Explorer
-- Manages rename, insert, export, and other batch operations

local BatchOperations = {}
BatchOperations.__index = BatchOperations

-- Load sub-modules
local BatchRename = require("BatchRename")
local BatchExport = require("BatchExport")

-- Constructor
function BatchOperations.new()
    local self = setmetatable({}, BatchOperations)
    
    -- Initialize sub-modules
    self.rename = BatchRename.new()
    self.export = BatchExport.new()
    
    -- Future sub-modules (placeholders)
    -- self.insert = BatchInsert.new()
    
    -- State
    self.active_operation = nil  -- "rename", "insert", "export", or nil
    self.selected_items = {}
    
    return self
end

-- ============================================================================
-- PUBLIC API - Rename Operations
-- ============================================================================

function BatchOperations:openRename(items)
    self.selected_items = items
    self.active_operation = "rename"
    self.rename:open(items)
end

-- ============================================================================
-- PUBLIC API - Export Operations
-- ============================================================================

function BatchOperations:openExport(items)
    self.selected_items = items
    self.active_operation = "export"
    self.export:open(items)
end


-- ============================================================================
-- PUBLIC API - Drawing
-- ============================================================================

function BatchOperations:draw(ctx)
    -- Draw active operation dialogs
    if self.rename:isOpen() then
        self.rename:draw(ctx)
    end
    
    if self.export:isOpen() then
        self.export:draw(ctx)
    end
    -- Future: draw other operation dialogs
    -- if self.insert and self.insert:isOpen() then
    --     self.insert:draw(ctx)
    -- end
end

-- ============================================================================
-- PUBLIC API - State Queries
-- ============================================================================

function BatchOperations:isOpen()
    return self.rename:isOpen() or self.export:isOpen()    -- Future: or self.insert:isOpen() or self.export:isOpen()
end

function BatchOperations:getActiveOperation()
    if self.rename:isOpen() then
        return "rename"
    end
    
    return nil
end

-- ============================================================================
-- PUBLIC API - Completion Detection
-- ============================================================================

function BatchOperations:wasRenamed()
    return self.rename:wasRenamed()
end

function BatchOperations:clearRenameFlag()
    self.rename:clearRenameFlag()
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

function BatchOperations:close()
    self.rename:close()
    self.active_operation = nil
end

return BatchOperations