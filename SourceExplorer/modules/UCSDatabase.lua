-- UCSDatabase.lua
-- Load and search UCS (Universal Category System) database
-- Parses UCS v8.2.1 CSV file (converted from spreadsheet)
-- PURE LUA - No Python dependencies!

local UCSDatabase = {}
UCSDatabase.__index = UCSDatabase

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

function UCSDatabase.new(csv_path)
    local self = setmetatable({}, UCSDatabase)
    
    self.categories = {}           -- All UCS categories
    self.by_catid = {}            -- Quick lookup by CatID
    self.by_category = {}         -- Grouped by main category
    self.recent_categories = {}   -- Recently used CatIDs
    self.max_recent = 10
    
    -- Load CSV if path provided
    if csv_path then
        self:load(csv_path)
    end
    
    return self
end

-- ============================================================================
-- CSV PARSING (Pure Lua)
-- ============================================================================

-- Parse a CSV line, handling quoted fields
-- @param line (string) - CSV line
-- @return (table) - Array of field values
local function parseCSVLine(line)
    local fields = {}
    local field = ""
    local in_quotes = false
    local i = 1
    
    while i <= #line do
        local char = line:sub(i, i)
        
        if char == '"' then
            if in_quotes and line:sub(i+1, i+1) == '"' then
                -- Escaped quote
                field = field .. '"'
                i = i + 1
            else
                -- Toggle quote state
                in_quotes = not in_quotes
            end
        elseif char == ',' and not in_quotes then
            -- End of field
            table.insert(fields, field)
            field = ""
        else
            field = field .. char
        end
        
        i = i + 1
    end
    
    -- Add last field
    table.insert(fields, field)
    
    return fields
end

-- ============================================================================
-- LOADING
-- ============================================================================

-- Load UCS CSV file
-- @param filepath (string) - Path to UCS .csv file
-- @return (boolean, string) - Success and error message
function UCSDatabase:load(filepath)
    -- Check if file exists
    local file = io.open(filepath, "r")
    if not file then
        return false, "UCS CSV file not found: " .. filepath
    end
    
    local line_num = 0
    local categories_loaded = 0
    
    for line in file:lines() do
        line_num = line_num + 1
        
        -- Skip header rows (first 3 lines)
        if line_num <= 3 then
            goto continue
        end
        
        -- Parse CSV line
        local fields = parseCSVLine(line)
        
        -- Skip empty lines
        if #fields < 3 or fields[1] == "" then
            goto continue
        end
        
        -- Extract fields
        local category = {
            category = fields[1] or "",
            subcategory = fields[2] or "",
            catid = fields[3] or "",
            catshort = fields[4] or "",
            explanation = fields[5] or "",
            synonyms = fields[6] or "",
        }
        
        -- Only add if we have a valid CatID
        if category.catid ~= "" then
            table.insert(self.categories, category)
            categories_loaded = categories_loaded + 1
        end
        
        ::continue::
    end
    
    file:close()
    
    -- Build indexes
    self:buildIndexes()
    
    return true, "Loaded " .. categories_loaded .. " UCS categories"
end

-- Build search indexes
function UCSDatabase:buildIndexes()
    self.by_catid = {}
    self.by_category = {}
    
    for _, cat in ipairs(self.categories) do
        -- Index by CatID
        self.by_catid[cat.catid] = cat
        
        -- Group by main category
        if not self.by_category[cat.category] then
            self.by_category[cat.category] = {}
        end
        table.insert(self.by_category[cat.category], cat)
    end
end

-- ============================================================================
-- SEARCH
-- ============================================================================

-- Search categories by query
-- @param query (string) - Search term
-- @return (table) - Array of matching categories
function UCSDatabase:search(query)
    if not query or query == "" then
        return self.categories
    end
    
    local query_lower = query:lower()
    local results = {}
    local seen = {}  -- Prevent duplicates
    
    for _, cat in ipairs(self.categories) do
        local match = false
        
        -- Match CatID
        if cat.catid:lower():find(query_lower, 1, true) then
            match = true
        end
        
        -- Match category name
        if not match and cat.category:lower():find(query_lower, 1, true) then
            match = true
        end
        
        -- Match subcategory name
        if not match and cat.subcategory:lower():find(query_lower, 1, true) then
            match = true
        end
        
        -- Match synonyms
        if not match and cat.synonyms:lower():find(query_lower, 1, true) then
            match = true
        end
        
        -- Match explanation
        if not match and cat.explanation:lower():find(query_lower, 1, true) then
            match = true
        end
        
        if match and not seen[cat.catid] then
            table.insert(results, cat)
            seen[cat.catid] = true
        end
    end
    
    return results
end

-- Get category by CatID
-- @param catid (string) - CatID to lookup
-- @return (table) - Category data or nil
function UCSDatabase:getCategory(catid)
    return self.by_catid[catid]
end

-- Get all categories grouped by main category
-- @return (table) - Categories grouped by main category name
function UCSDatabase:getCategoriesGrouped()
    return self.by_category
end

-- Get all main category names
-- @return (table) - Array of category names
function UCSDatabase:getMainCategories()
    local names = {}
    for name, _ in pairs(self.by_category) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Get subcategories for a main category
-- @param category_name (string) - Main category name
-- @return (table) - Array of subcategories
function UCSDatabase:getSubcategories(category_name)
    return self.by_category[category_name] or {}
end

-- ============================================================================
-- SYNONYMS
-- ============================================================================

-- Get synonyms for a CatID
-- @param catid (string) - CatID to get synonyms for
-- @return (table) - Array of synonym strings
function UCSDatabase:getSynonyms(catid)
    local cat = self:getCategory(catid)
    if not cat or not cat.synonyms or cat.synonyms == "" then
        return {}
    end
    
    -- Split by comma
    local synonyms = {}
    for synonym in cat.synonyms:gmatch("[^,]+") do
        local trimmed = synonym:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            table.insert(synonyms, trimmed)
        end
    end
    
    return synonyms
end

-- ============================================================================
-- RECENT CATEGORIES
-- ============================================================================

-- Add category to recent list
-- @param catid (string) - CatID to add
function UCSDatabase:addRecent(catid)
    -- Remove if already exists
    for i, id in ipairs(self.recent_categories) do
        if id == catid then
            table.remove(self.recent_categories, i)
            break
        end
    end
    
    -- Add to front
    table.insert(self.recent_categories, 1, catid)
    
    -- Trim to max
    while #self.recent_categories > self.max_recent do
        table.remove(self.recent_categories)
    end
end

-- Get recent categories
-- @return (table) - Array of recent category objects
function UCSDatabase:getRecent()
    local recent = {}
    
    for _, catid in ipairs(self.recent_categories) do
        local cat = self:getCategory(catid)
        if cat then
            table.insert(recent, cat)
        end
    end
    
    return recent
end

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Get total category count
-- @return (number) - Number of categories
function UCSDatabase:getCount()
    return #self.categories
end

-- Check if database is loaded
-- @return (boolean) - True if categories loaded
function UCSDatabase:isLoaded()
    return #self.categories > 0
end

-- Get category display name
-- @param catid (string) - CatID
-- @return (string) - Display name (e.g., "GUNS-AUTOMATIC")
function UCSDatabase:getDisplayName(catid)
    local cat = self:getCategory(catid)
    if not cat then
        return catid
    end
    
    return cat.category .. "-" .. cat.subcategory
end

return UCSDatabase