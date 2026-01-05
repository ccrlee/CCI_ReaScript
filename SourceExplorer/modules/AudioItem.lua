-- AudioItem.lua
-- Data model for audio items in Source Explorer

local AudioItem = {}
AudioItem.__index = AudioItem

-- Load Utils for helper functions
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"
local Utils = require("Utils")
local UCSMetadata = require("UCSMetadata")

-- Default values for new items
local defaults = {
    file = "",
    takeName = "",
    tk = nil,
    index = -1,
    chunk = "",
    item = nil,
    favorite = false,
    collections = {},
    ucs = nil,  -- UCSMetadata object or nil
}

-- Constructor
function AudioItem.new(config)
    config = config or {}
    
    local self = setmetatable({}, AudioItem)
    
    -- Apply defaults, then overrides from config
    for key, default_value in pairs(defaults) do
        self[key] = config[key] ~= nil and config[key] or default_value
    end
    
    if type(self.collections) ~= 'table' then
        self.collections = {}
    end

    return self
end

-- Get just the filename from full path
function AudioItem:getFileName()
    return Utils.GetFileNameFromPath(self.file)
end

-- Get item properties extracted from chunk
function AudioItem:getProperties()
    return Utils.GetItemPropertiesFromChunk(self.chunk)
end

-- Get source offset and length from chunk
function AudioItem:getSourceOffset()
    return Utils.GetSourceOffsetFromChunk(self.chunk)
end

-- Check if this item has valid data
function AudioItem:isValid()
    return self.file ~= "" and self.chunk ~= ""
end

-- Get duration of the item
function AudioItem:getDuration()
    local props = self:getProperties()
    if props then
        return props.item_length
    end
    return 0
end

-- Get display name (takeName if available, otherwise filename)
function AudioItem:getDisplayName()
    if self.takeName and self.takeName ~= "" then
        return self.takeName
    end
    return self:getFileName()
end

-- Toggle favorite status
function AudioItem:toggleFavorite()
    self.favorite = not self.favorite
    
    if self.favorite then
        self:addToCollection("FAVORITES")
    else
        self:removeFromCollection("FAVORITES")
    end
end

-- Create a formatted info string
function AudioItem:getInfoString()
    local props = self:getProperties()
    if not props then
        return "No properties available"
    end
    
    local info = {}
    table.insert(info, string.format("Duration: %.2fs", props.item_length))
    table.insert(info, string.format("Offset: %.2fs", props.source_offset))
    
    if props.playback_rate ~= 1.0 then
        table.insert(info, string.format("Rate: %.2fx", props.playback_rate))
    end
    
    if props.fade_in > 0 then
        table.insert(info, string.format("Fade In: %.2fs", props.fade_in))
    end
    
    if props.fade_out > 0 then
        table.insert(info, string.format("Fade Out: %.2fs", props.fade_out))
    end
    
    return table.concat(info, " | ")
end

-- Convert to a simple table for serialization
function AudioItem:toTable()
    local tbl = {
        file = self.file,
        takeName = self.takeName,
        tk = self.tk,
        index = self.index,
        chunk = self.chunk,
        item = self.item,
        favorite = self.favorite,
        collections = self.collections,
    }
    
    -- Serialize UCS metadata if present
    if self.ucs then
        tbl.ucs = self.ucs:toTable()
    end
    
    return tbl
end

-- Create AudioItem from a simple table (after deserialization)
function AudioItem.fromTable(tbl)
    if not tbl then
        return nil
    end
    
    local item = AudioItem.new(tbl)
    
    -- Deserialize UCS metadata if present
    if tbl.ucs then
        item.ucs = UCSMetadata.fromTable(tbl.ucs)
    end
    
    return item
end

-- Batch create AudioItems from REAPER selection
function AudioItem.fromReaperSelection()
    -- Check if ultraschall is available
    if not ultraschall then
        Utils.Msg("Ultraschall API not found", true)
        return {}
    end
    
    local items = {}
    local itemCount = reaper.CountSelectedMediaItems(0)
    
    if itemCount < 1 then 
        return items 
    end

    for i = 0, itemCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local itemIndex = ultraschall.GetItem_Number(item)
        local take = reaper.GetMediaItemTake(item, 0)
        
        if take then
            local source = reaper.GetMediaItemTake_Source(take)
            local fileName = reaper.GetMediaSourceFileName(source)
            local _, chunk = reaper.GetItemStateChunk(item, 'chunk')
            local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', '', false)
            
            if fileName ~= '' then
                local audioItem = AudioItem.new({
                    file = fileName,
                    takeName = takeName,
                    tk = take,
                    index = itemIndex,
                    chunk = chunk,
                    item = item,
                    favorite = false,
                    collections = {},
                })
                
                table.insert(items, audioItem)
            end
        end
    end
    
    return items
end


-- ============================================================================
-- COLLECTION MANAGEMENT METHODS
-- ============================================================================

function AudioItem:addToCollection(collection_id)
    if not self:isInCollection(collection_id) then
        table.insert(self.collections, collection_id)
        
        -- Auto-sync: Adding to FAVORITES sets favorite flag
        if collection_id == "FAVORITES" then
            self.favorite = true
        end
        
        return true
    end
    return false
end

function AudioItem:removeFromCollection(collection_id)
    for i, id in ipairs(self.collections) do
        if id == collection_id then
            table.remove(self.collections, i)
            
            -- Auto-sync: Removing from FAVORITES clears favorite flag
            if collection_id == "FAVORITES" then
                self.favorite = false
            end
            
            return true
        end
    end
    return false
end

function AudioItem:isInCollection(collection_id)
    for _, id in ipairs(self.collections) do
        if id == collection_id then
            return true
        end
    end
    return false
end

function AudioItem:getCollections()
    return self.collections
end

function AudioItem:getCollectionCount()
    return #self.collections
end

function AudioItem:removeFromAllCollections()
    local count = #self.collections
    self.collections = {}
    return count
end

function AudioItem:isInAnyCollection(collection_ids)
    for _, check_id in ipairs(collection_ids) do
        if self:isInCollection(check_id) then
            return true
        end
    end
    return false
end

-- ============================================================================
-- UCS METADATA METHODS
-- ============================================================================

-- Check if this item has UCS metadata
-- @return (boolean) - True if UCS data exists
function AudioItem:hasUCS()
    return self.ucs ~= nil and self.ucs:hasData()
end

-- Get or create UCS metadata
-- @return (UCSMetadata) - UCS metadata object
function AudioItem:getOrCreateUCS()
    if not self.ucs then
        self.ucs = UCSMetadata.new()
    end
    return self.ucs
end

-- Get UCS status for display
-- @return (string) - "complete", "incomplete", or "not_set"
function AudioItem:getUCSStatus()
    if not self.ucs or not self.ucs:hasData() then
        return "not_set"
    end
    
    if self.ucs:isComplete() then
        return "complete"
    end
    
    return "incomplete"
end

-- Get UCS filename preview (without extension)
-- @return (string) - UCS filename or nil
function AudioItem:getUCSFilename()
    if not self.ucs then
        return nil
    end
    
    return self.ucs:buildFilename()
end

return AudioItem