-- RegionCreator.lua
-- Creates REAPER regions with full UCS metadata embedded in region names

local RegionCreator = {}
RegionCreator.__index = RegionCreator

-- Constructor
function RegionCreator.new()
    local self = setmetatable({}, RegionCreator)
    
    -- State
    self.created_regions = {}
    self.last_error = nil
    
    return self
end

-- ============================================================================
-- PUBLIC API - Region Creation
-- ============================================================================

-- Create regions from AudioItem array
-- @param audio_items (table) - Array of AudioItem objects
-- @param options (table) - Configuration options
-- @return (boolean, string) - Success, message
function RegionCreator:createRegionsFromItems(audio_items, options)
    if not audio_items or #audio_items == 0 then
        return false, "No items provided"
    end
    
    -- Default options
    options = options or {}
    local start_position = options.start_position or reaper.GetCursorPosition()
    local spacing = options.spacing or 0.5
    local auto_number = options.auto_number ~= false  -- Default true
    local start_number = options.start_number or 1
    local include_metadata = options.include_metadata ~= false  -- Default true
    local metadata_fields = options.metadata_fields or "all"  -- "all", "core", or custom table
    
    self.created_regions = {}
    local current_position = start_position
    local current_number = start_number
    
    reaper.Undo_BeginBlock()
    
    for i, audio_item in ipairs(audio_items) do
        -- Get item duration
        local duration = audio_item:getDuration()
        
        if duration > 0 then
            -- Build region name
            local region_name = self:formatRegionName(
                audio_item, 
                current_number, 
                {
                    auto_number = auto_number,
                    include_metadata = include_metadata,
                    metadata_fields = metadata_fields
                }
            )
            
            -- Create region
            local region_idx = reaper.AddProjectMarker2(
                0,  -- project
                true,  -- isrgn
                current_position,  -- pos
                current_position + duration,  -- rgnend
                region_name,  -- name
                -1,  -- wantidx
                0  -- color
            )
            
            if region_idx >= 0 then
                table.insert(self.created_regions, {
                    index = region_idx,
                    name = region_name,
                    start_pos = current_position,
                    end_pos = current_position + duration,
                    audio_item = audio_item
                })
                
                -- Advance position
                current_position = current_position + duration + spacing
                current_number = current_number + 1
            else
                self.last_error = "Failed to create region for item: " .. audio_item:getDisplayName()
            end
        end
    end
    
    reaper.Undo_EndBlock("Create Regions from Source Explorer Items", -1)
    
    local count = #self.created_regions
    return count > 0, string.format("Created %d region%s", count, count == 1 and "" or "s")
end

-- Insert items to timeline AND create matching regions
-- @param audio_items (table) - Array of AudioItem objects
-- @param options (table) - Configuration options
-- @return (boolean, string) - Success, message
function RegionCreator:insertItemsWithRegions(audio_items, options)
    if not audio_items or #audio_items == 0 then
        return false, "No items provided"
    end
    
    -- Default options
    options = options or {}
    local start_position = options.start_position or reaper.GetCursorPosition()
    local spacing = options.spacing or 0.5
    local target_track = options.target_track or reaper.GetSelectedTrack(0, 0)
    
    if not target_track then
        return false, "No track selected. Please select a target track."
    end
    
    reaper.Undo_BeginBlock()
    
    local current_position = start_position
    local inserted_items = {}
    
    -- Insert items to timeline
    for i, audio_item in ipairs(audio_items) do
        local item_props = audio_item:getProperties()
        
        if item_props then
            -- Create new media item
            local new_item = reaper.AddMediaItemToTrack(target_track)
            
            if new_item then
                -- Add take from source file
                local take = reaper.AddTakeToMediaItem(new_item)
                local source = reaper.PCM_Source_CreateFromFile(audio_item.file)
                
                if source and take then
                    reaper.SetMediaItemTake_Source(take, source)
                    
                    -- Set item position and length
                    reaper.SetMediaItemInfo_Value(new_item, "D_POSITION", current_position)
                    reaper.SetMediaItemInfo_Value(new_item, "D_LENGTH", item_props.item_length)
                    
                    -- Set take name
                    if audio_item.takeName and audio_item.takeName ~= "" then
                        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", audio_item.takeName, true)
                    end
                    
                    -- Apply item properties from chunk
                    reaper.SetMediaItemInfo_Value(new_item, "D_VOL", item_props.volume)
                    reaper.SetMediaItemInfo_Value(new_item, "D_FADEINLEN", item_props.fade_in)
                    reaper.SetMediaItemInfo_Value(new_item, "D_FADEOUTLEN", item_props.fade_out)
                    reaper.SetMediaItemInfo_Value(new_item, "C_BEATATTACHMODE", item_props.playback_rate)
                    
                    -- Set source offset
                    reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", item_props.source_offset)
                    
                    table.insert(inserted_items, {
                        item = new_item,
                        audio_item = audio_item,
                        position = current_position
                    })
                    
                    -- Advance position
                    current_position = current_position + item_props.item_length + spacing
                else
                    reaper.DeleteTrackMediaItem(target_track, new_item)
                end
            end
        end
    end
    
    -- Now create regions for inserted items
    local region_result, region_msg = self:createRegionsFromItems(audio_items, options)
    
    reaper.Undo_EndBlock("Insert Items with Regions from Source Explorer", -1)
    reaper.UpdateArrange()
    
    local count = #inserted_items
    local result_msg = string.format("Inserted %d item%s", count, count == 1 and "" or "s")
    if region_result then
        result_msg = result_msg .. " and " .. region_msg
    end
    
    return count > 0, result_msg
end

-- ============================================================================
-- REGION NAME FORMATTING
-- ============================================================================

-- Format region name with UCS metadata
-- @param audio_item (AudioItem) - Source item
-- @param index (number) - Sequential number
-- @param options (table) - Formatting options
-- @return (string) - Formatted region name
function RegionCreator:formatRegionName(audio_item, index, options)
    options = options or {}
    
    -- Start with UCS filename or item name
    local region_name = ""
    
    if audio_item:hasUCS() then
        -- Build UCS filename
        region_name = audio_item:getUCSFilename() or audio_item:getDisplayName()
        
        -- Add sequential number if requested
        if options.auto_number then
            -- Check if filename already has numbering
            if not region_name:match("_%d+$") then
                region_name = region_name .. string.format("_%02d", index)
            end
        end
    else
        -- No UCS data, use display name + number
        region_name = audio_item:getDisplayName()
        if options.auto_number then
            region_name = region_name .. string.format("_%02d", index)
        end
    end
    
    -- Add metadata in REAPER name=value; format if requested
    if options.include_metadata and audio_item:hasUCS() then
        local metadata_string = self:buildMetadataWildcards(
            audio_item.ucs, 
            options.metadata_fields
        )
        
        if metadata_string ~= "" then
            -- REAPER format: "DisplayName FieldName=value;FieldName2=value2;..."
            -- region_name = region_name .. " " .. metadata_string
            region_name = metadata_string
        end
    end
    
    return region_name
end

-- Build metadata string from UCS data in REAPER name=value; format
-- @param ucs (UCSMetadata) - UCS metadata object
-- @param fields (string|table) - "all", "core", or table of field names
-- @return (string) - Metadata string in name=value; format
function RegionCreator:buildMetadataWildcards(ucs, fields)
    if not ucs then
        return ""
    end
    
    fields = fields or "all"
    
    local metadata_pairs = {}
    
    -- Determine which fields to include
    local field_list = {}
    
    if fields == "all" then
        field_list = self:getAllMetadataFields()
    elseif fields == "core" then
        field_list = self:getCoreMetadataFields()
    elseif type(fields) == "table" then
        field_list = fields
    end
    
    -- Build name=value pairs for each field
    for _, field_name in ipairs(field_list) do
        local value = self:getFieldValue(ucs, field_name)
        
        -- Only add if value exists and is non-empty
        if value and value ~= "" then
            -- Format: FieldName=value
            local pair = string.format("%s=%s", field_name, value)
            table.insert(metadata_pairs, pair)
        end
    end
    
    -- Join with semicolons
    if #metadata_pairs > 0 then
        return table.concat(metadata_pairs, ";")
    end
    
    return ""
end

-- Get value for a metadata field
-- @param ucs (UCSMetadata) - UCS metadata object
-- @param field_name (string) - Field name
-- @return (string) - Field value or empty string
function RegionCreator:getFieldValue(ucs, field_name)
    local field_map = {
        -- Core UCS
        UCSName = ucs:buildFilename(false, 0),
        CatID = ucs.catid,
        Category = ucs.category,
        SubCategory = ucs.subcategory,
        FXName = ucs.fxname,
        ShortID = ucs.creator_id,
        Library = ucs.source_id,
        
        -- Optional UCS
        UserCategory = ucs.user_category,
        VendorCategory = ucs.vendor_category,
        Notes = ucs.user_data,
        
        -- Extended metadata
        Keywords = ucs:getKeywordsString(),
        Description = ucs.description,
    }
    
    return field_map[field_name] or ""
end

-- Get core metadata field list
-- @return (table) - Array of field names
function RegionCreator:getCoreMetadataFields()
    return {
        "UCSName",
        "CatID",
        "Category",
        "SubCategory",
        "FXName",
        "ShortID",
        "Library"
    }
end

-- Get all metadata field list
-- @return (table) - Array of field names
function RegionCreator:getAllMetadataFields()
    return {
        "UCSName",
        "CatID",
        "Category",
        "SubCategory",
        "UserCategory",
        "VendorCategory",
        "FXName",
        "ShortID",
        "Library",
        "Notes",
        "Keywords",
        "Description"
    }
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

-- Validate items for export
-- @param audio_items (table) - Array of AudioItem objects
-- @return (boolean, table) - Valid flag, issues table
function RegionCreator:validateItems(audio_items)
    local issues = {
        no_ucs = {},
        incomplete_ucs = {},
        missing_fields = {}
    }
    
    for i, audio_item in ipairs(audio_items) do
        if not audio_item:hasUCS() then
            table.insert(issues.no_ucs, audio_item:getDisplayName())
        else
            -- Check completeness
            local ucs = audio_item.ucs
            local missing = {}
            
            if not ucs.catid or ucs.catid == "" then
                table.insert(missing, "CatID")
            end
            if not ucs.category or ucs.category == "" then
                table.insert(missing, "Category")
            end
            if not ucs.subcategory or ucs.subcategory == "" then
                table.insert(missing, "SubCategory")
            end
            if not ucs.fxname or ucs.fxname == "" then
                table.insert(missing, "FX Name")
            end
            if not ucs.creator_id or ucs.creator_id == "" then
                table.insert(missing, "Creator ID")
            end
            if not ucs.source_id or ucs.source_id == "" then
                table.insert(missing, "Source ID")
            end
            
            if #missing > 0 then
                table.insert(issues.incomplete_ucs, {
                    name = audio_item:getDisplayName(),
                    missing = missing
                })
            end
        end
    end
    
    -- Calculate overall validity
    local has_issues = #issues.no_ucs > 0 or #issues.incomplete_ucs > 0
    
    return not has_issues, issues
end

-- Get validation summary string
-- @param issues (table) - Issues from validateItems
-- @return (string) - Human-readable summary
function RegionCreator:getValidationSummary(issues)
    local lines = {}
    
    if #issues.no_ucs > 0 then
        table.insert(lines, string.format("⚠️ %d item%s without UCS metadata:", 
            #issues.no_ucs, 
            #issues.no_ucs == 1 and "" or "s"))
        
        for _, name in ipairs(issues.no_ucs) do
            table.insert(lines, "  • " .. name)
        end
        table.insert(lines, "")
    end
    
    if #issues.incomplete_ucs > 0 then
        table.insert(lines, string.format("⚠️ %d item%s with incomplete UCS metadata:", 
            #issues.incomplete_ucs,
            #issues.incomplete_ucs == 1 and "" or "s"))
        
        for _, item in ipairs(issues.incomplete_ucs) do
            table.insert(lines, "  • " .. item.name)
            table.insert(lines, "    Missing: " .. table.concat(item.missing, ", "))
        end
    end
    
    return table.concat(lines, "\n")
end

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Get created regions
-- @return (table) - Array of region data
function RegionCreator:getCreatedRegions()
    return self.created_regions
end

-- Clear created regions list
function RegionCreator:clear()
    self.created_regions = {}
    self.last_error = nil
end

-- Get last error message
-- @return (string) - Error message or nil
function RegionCreator:getLastError()
    return self.last_error
end

return RegionCreator