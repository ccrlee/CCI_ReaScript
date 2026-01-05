-- UCSMetadata.lua
-- Standalone UCS metadata object for Universal Category System
-- Can be used in any project that needs UCS support

local UCSMetadata = {}
UCSMetadata.__index = UCSMetadata

-- ============================================================================
-- REQUIRED FIELDS DEFINITION
-- ============================================================================

UCSMetadata.REQUIRED_FIELDS = {
    "catid",
    "category",
    "subcategory",
    "fxname",
    "creator_id",
    "source_id"
}
-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

function UCSMetadata.new(config)
    config = config or {}
    
    local self = setmetatable({}, UCSMetadata)
    
    -- Required fields
    self.catid = config.catid or ""              -- e.g., "GUNAuto"
    self.category = config.category or ""        -- e.g., "GUNS" (parsed)
    self.subcategory = config.subcategory or ""  -- e.g., "AUTOMATIC" (parsed)
    self.fxname = config.fxname or ""            -- Brief description
    self.creator_id = config.creator_id or ""    -- Sound designer/recordist
    self.source_id = config.source_id or ""      -- Project/library name
    
    -- Optional fields
    self.user_category = config.user_category or ""      -- e.g., "-INT", "-EXT"
    self.vendor_category = config.vendor_category or ""  -- Library-specific
    self.user_data = config.user_data or ""              -- Freeform
    
    -- Extended metadata
    self.keywords = config.keywords or {}        -- Array of keywords
    self.description = config.description or ""  -- Detailed description
    
    return self
end

-- ============================================================================
-- FILENAME GENERATION
-- ============================================================================

-- Build full UCS compliant filename
-- Format: CatID(-UserCategory)_(VendorCategory-)FXName_CreatorID_SourceID(_UserData)
-- @return (string) - UCS filename without extension
function UCSMetadata:buildFilename(shouldNumber, index)
    local parts = {}
    
    -- Part 1: CatID (required)
    if self.catid == "" then
        return nil, "CatID is required"
    end
    
    local catid_part = self.catid
    
    -- Add optional UserCategory
    if self.user_category and self.user_category ~= "" then
        catid_part = catid_part .. "-" .. self.user_category
    end
    
    table.insert(parts, catid_part)
    
    -- Part 2: FX Name (with optional VendorCategory prefix)
    local fxname_part = ""
    
    if self.vendor_category and self.vendor_category ~= "" then
        fxname_part = self.vendor_category .. "-"
    end
    
    if self.fxname and self.fxname ~= "" then
        fxname_part = fxname_part .. self.fxname
    end

    if shouldNumber and index ~= nil and index ~= '' then
        fxname_part = fxname_part .. string.format("_%02d", index)
    end
    
    if fxname_part ~= "" then
        table.insert(parts, fxname_part)
    end
    
    -- Part 3: Creator ID
    if self.creator_id and self.creator_id ~= "" then
        table.insert(parts, self.creator_id)
    end
    
    -- Part 4: Source ID
    if self.source_id and self.source_id ~= "" then
        table.insert(parts, self.source_id)
    end
    
    -- Part 5: Optional User Data
    if self.user_data and self.user_data ~= "" then
        table.insert(parts, self.user_data)
    end
    
    -- Join with underscores
    return table.concat(parts, "_")
end

-- ============================================================================
-- FILENAME PARSING
-- ============================================================================

-- Parse UCS filename into components
-- @param filename (string) - UCS filename to parse
-- @return (boolean) - Success/failure
function UCSMetadata:parse(filename)
    if not filename or filename == "" then
        return false
    end
    
    -- Remove file extension
    local name_without_ext = filename:match("(.+)%..+$") or filename
    
    -- Split by underscores
    local parts = {}
    for part in name_without_ext:gmatch("[^_]+") do
        table.insert(parts, part)
    end
    
    if #parts < 1 then
        return false
    end
    
    -- Part 1: CatID (and optional UserCategory)
    local catid_part = parts[1]
    local catid, user_cat = catid_part:match("^([^%-]+)%-(.+)$")
    
    if catid then
        self.catid = catid
        self.user_category = user_cat
    else
        self.catid = catid_part
    end
    
    -- Part 2: FX Name (and optional VendorCategory)
    if #parts >= 2 then
        local fxname_part = parts[2]
        local vendor_cat, fxname = fxname_part:match("^([^%-]+)%-(.+)$")
        
        if vendor_cat then
            self.vendor_category = vendor_cat
            self.fxname = fxname
        else
            self.fxname = fxname_part
        end
    end
    
    -- Part 3: Creator ID
    if #parts >= 3 then
        self.creator_id = parts[3]
    end
    
    -- Part 4: Source ID
    if #parts >= 4 then
        self.source_id = parts[4]
    end
    
    -- Part 5+: User Data (everything else joined)
    if #parts >= 5 then
        local user_data_parts = {}
        for i = 5, #parts do
            table.insert(user_data_parts, parts[i])
        end
        self.user_data = table.concat(user_data_parts, "_")
    end
    
    return true
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

-- Check if UCS metadata is valid
-- @return (boolean, string) - Valid flag and error message
function UCSMetadata:isValid()
    -- CatID is required
    if not self.catid or self.catid == "" then
        return false, "CatID is required"
    end
    
    -- Check for invalid characters in CatID (should be alphanumeric)
    if self.catid:match("[^%w]") then
        return false, "CatID contains invalid characters"
    end
    
    -- FX Name should not be too long (recommended max 25 chars)
    if self.fxname and #self.fxname > 25 then
        return false, "FX Name exceeds recommended 25 characters (" .. #self.fxname .. ")"
    end
    
    -- Check for invalid filename characters
    local invalid_chars = '[/\\:*?"<>|]'
    
    if self.fxname and self.fxname:match(invalid_chars) then
        return false, "FX Name contains invalid filename characters"
    end
    
    if self.creator_id and self.creator_id:match(invalid_chars) then
        return false, "Creator ID contains invalid filename characters"
    end
    
    if self.source_id and self.source_id:match(invalid_chars) then
        return false, "Source ID contains invalid filename characters"
    end
    
    return true, "Valid"
end

-- Check if metadata is complete (has all common fields)
-- @return (boolean) - True if complete
function UCSMetadata:isComplete()
    for _, field_name in ipairs(UCSMetadata.REQUIRED_FIELDS) do
        local value = self[field_name]
        if not value or value == "" then
            return false, field_name
        end
    end
end

-- Get array of all missing required fields
-- Returns: array of field names (empty array if complete)
function UCSMetadata:getMissingFields()
    local missing_fields = {}

    for _, field_name in ipairs(UCSMetadata.REQUIRED_FIELDS) do
        local value = self[field_name]
        if not value or value == "" then
            table.insert(missing_fields, field_name)
        end
    end
    
    return missing_fields
end

-- Check if any UCS data exists
-- @return (boolean) - True if any field is set
function UCSMetadata:hasData()
    return self.catid ~= "" or
           self.fxname ~= "" or
           self.creator_id ~= "" or
           self.source_id ~= "" or
           #self.keywords > 0 or
           self.description ~= ""
end

-- ============================================================================
-- KEYWORDS
-- ============================================================================

-- Add keyword if not already present
-- @param keyword (string) - Keyword to add
-- @return (boolean) - True if added, false if already exists
function UCSMetadata:addKeyword(keyword)
    if not keyword or keyword == "" then
        return false
    end
    
    -- Check if already exists (case-insensitive)
    local keyword_lower = keyword:lower()
    for _, kw in ipairs(self.keywords) do
        if kw:lower() == keyword_lower then
            return false
        end
    end
    
    table.insert(self.keywords, keyword)
    return true
end

-- Remove keyword
-- @param keyword (string) - Keyword to remove
-- @return (boolean) - True if removed
function UCSMetadata:removeKeyword(keyword)
    if not keyword then
        return false
    end
    
    local keyword_lower = keyword:lower()
    for i, kw in ipairs(self.keywords) do
        if kw:lower() == keyword_lower then
            table.remove(self.keywords, i)
            return true
        end
    end
    
    return false
end

-- Get keywords as comma-separated string
-- @return (string) - Keywords joined by comma
function UCSMetadata:getKeywordsString()
    if #self.keywords == 0 then
        return ""
    end
    return table.concat(self.keywords, ", ")
end

-- Set keywords from comma-separated string
-- @param keywords_str (string) - Comma-separated keywords
function UCSMetadata:setKeywordsFromString(keywords_str)
    self.keywords = {}
    
    if not keywords_str or keywords_str == "" then
        return
    end
    
    -- Split by comma and trim whitespace
    for keyword in keywords_str:gmatch("[^,]+") do
        local trimmed = keyword:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            table.insert(self.keywords, trimmed)
        end
    end
end

-- ============================================================================
-- SERIALIZATION
-- ============================================================================

-- Convert to table for serialization
-- @return (table) - Plain table representation
function UCSMetadata:toTable()
    return {
        catid = self.catid,
        category = self.category,
        subcategory = self.subcategory,
        fxname = self.fxname,
        creator_id = self.creator_id,
        source_id = self.source_id,
        user_category = self.user_category,
        vendor_category = self.vendor_category,
        user_data = self.user_data,
        keywords = self.keywords,
        description = self.description,
    }
end

-- Create from table (after deserialization)
-- @param tbl (table) - Table with UCS data
-- @return (UCSMetadata) - New UCSMetadata object
function UCSMetadata.fromTable(tbl)
    if not tbl then
        return nil
    end
    
    return UCSMetadata.new(tbl)
end

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Clone this UCS metadata
-- @return (UCSMetadata) - New copy of this object
function UCSMetadata:clone()
    return UCSMetadata.new(self:toTable())
end

-- Clear all UCS data
function UCSMetadata:clear()
    self.catid = ""
    self.category = ""
    self.subcategory = ""
    self.fxname = ""
    self.creator_id = ""
    self.source_id = ""
    self.user_category = ""
    self.vendor_category = ""
    self.user_data = ""
    self.keywords = {}
    self.description = ""
end

-- Get a summary string for display
-- @return (string) - Human-readable summary
function UCSMetadata:getSummary()
    if not self:hasData() then
        return "No UCS data"
    end
    
    local parts = {}
    
    if self.category ~= "" and self.subcategory ~= "" then
        table.insert(parts, self.category .. "-" .. self.subcategory)
    elseif self.catid ~= "" then
        table.insert(parts, self.catid)
    end
    
    if self.fxname ~= "" then
        table.insert(parts, self.fxname)
    end
    
    if #parts == 0 then
        return "Incomplete UCS data"
    end
    
    return table.concat(parts, " | ")
end

return UCSMetadata