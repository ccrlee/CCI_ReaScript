-- BatchExport.lua
-- Batch export dialog and workflow for Source Explorer
-- Creates regions with metadata and configures render settings

local BatchExport = {}
BatchExport.__index = BatchExport

-- Load dependencies
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"
local RegionCreator = require("RegionCreator")

-- ============================================================================
-- iXML METADATA MAPPING
-- ============================================================================
-- Maps file metadata fields to UCS field names
-- This tells REAPER which metadata fields to populate from region/marker data
local iXML = {
    -- Core UCS fields (iXML format)
    ["IXML:USER:CatID"] = "CatID",
    ["IXML:USER:Category"] = "Category",
    ["IXML:USER:SubCategory"] = "SubCategory",
    ["IXML:USER:CategoryFull"] = "CategoryFull",
    ["IXML:USER:FXName"] = "FXName",
    ["IXML:USER:Notes"] = "Notes",
    ["IXML:USER:Show"] = "Library",  -- Source ID
    ["IXML:USER:UserCategory"] = "UserCategory",
    ["IXML:USER:VendorCategory"] = "VendorCategory",
    
    -- Extended metadata fields
    ["IXML:USER:TrackTitle"] = "TrackTitle",
    ["IXML:USER:Description"] = "Description",
    ["IXML:USER:Keywords"] = "Keywords",
    ["IXML:USER:Microphone"] = "Microphone",
    ["IXML:USER:Designer"] = "Designer",
    ["IXML:USER:ShortID"] = "ShortID",
    ["IXML:USER:Library"] = "Library",
    
    -- Duplicates for compatibility
    ["IXML:USER:LongID"] = "CatID",
    ["IXML:USER:Source"] = "Library",
    
    -- BWF (Broadcast Wave Format) fields
    ["BWF:Description"] = "Description",
    ["BWF:Originator"] = "Designer",
    
    -- ID3 tags (for MP3)
    ["ID3:TIT2"] = "TrackTitle",  -- Title
    ["ID3:COMM"] = "Description",  -- Comment
    ["ID3:TPE1"] = "Designer",     -- Artist
    ["ID3:TPE2"] = "Library",      -- Album Artist
    ["ID3:TCON"] = "Category",     -- Genre
    ["ID3:TALB"] = "Library",      -- Album
    
    -- INFO (RIFF INFO for WAV/AVI)
    ["INFO:ICMT"] = "Description", -- Comment
    ["INFO:IART"] = "Designer",    -- Artist
    ["INFO:IGNR"] = "Category",    -- Genre
    ["INFO:INAM"] = "TrackTitle",  -- Title
    ["INFO:IPRD"] = "Library",     -- Product (Album)
    
    -- XMP (Adobe metadata)
    ["XMP:dc/description"] = "Description",
    ["XMP:dm/artist"] = "Designer",
    ["XMP:dm/genre"] = "Category",
    ["XMP:dc/title"] = "TrackTitle",
    ["XMP:dm/album"] = "Library",
    
    -- VORBIS (for OGG)
    ["VORBIS:DESCRIPTION"] = "Description",
    ["VORBIS:COMMENT"] = "Description",
    ["VORBIS:GENRE"] = "Category",
    ["VORBIS:TITLE"] = "TrackTitle",
    ["VORBIS:ARTIST"] = "Designer",
    ["VORBIS:ALBUM"] = "Library",
}

-- Constructor
function BatchExport.new(config)
    local self = setmetatable({}, BatchExport)
    
    self.config = config or {}
    self.region_creator = RegionCreator.new()
    
    -- Dialog state
    self.is_open = false
    self.selected_items = {}
    
    -- Export settings
    self.settings = {
        start_position = 0,  -- 0 = cursor, 1 = project start
        spacing = 0.5,
        auto_number = true,
        start_number = 1,
        include_metadata = true,
        metadata_fields = "all",  -- "all" or "core"
        metadata_source = "region",  -- "region" or "marker"
        insert_items = true,
        create_regions = true,
        target_track_mode = 0,  -- 0 = selected, 1 = new track
        set_render_preset = true,
        open_render_dialog = false,
        render_pattern = "$region(Category)[;]/$region(SubCategory)[;]/$region",  -- Default pattern with folder structure
    }
    
    -- Validation
    self.validation_result = nil
    self.validation_issues = nil
    self.show_validation_warning = false
    self.user_confirmed = false
    
    return self
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Open export dialog
-- @param items (table) - Array of selected AudioItem objects
function BatchExport:open(items)
    if not items or #items == 0 then
        return
    end
    
    self.selected_items = items
    self.is_open = true
    self.user_confirmed = false
    
    -- Set default start position to cursor
    self.settings.start_position = 0
    
    -- Validate items
    self.validation_result, self.validation_issues = 
        self.region_creator:validateItems(items)
    
    -- Show warning if validation failed
    self.show_validation_warning = not self.validation_result
end

-- Close dialog
function BatchExport:close()
    self.is_open = false
    self.selected_items = {}
    self.validation_result = nil
    self.validation_issues = nil
    self.show_validation_warning = false
    self.user_confirmed = false
end

-- Check if dialog is open
-- @return (boolean)
function BatchExport:isOpen()
    return self.is_open
end

-- ============================================================================
-- EXECUTION
-- ============================================================================

-- Execute the export
-- @return (boolean, string) - Success, message
function BatchExport:execute()
    if #self.selected_items == 0 then
        return false, "No items selected"
    end
    
    -- Get start position
    local start_pos
    if self.settings.start_position == 0 then
        start_pos = reaper.GetCursorPosition()
    else
        start_pos = 0  -- Project start
    end
    
    -- Get or create target track
    local target_track = nil
    if self.settings.insert_items then
        if self.settings.target_track_mode == 0 then
            -- Use selected track
            target_track = reaper.GetSelectedTrack(0, 0)
            if not target_track then
                return false, "No track selected. Please select a target track or choose 'New Track' option."
            end
        else
            -- Create new track
            reaper.InsertTrackAtIndex(reaper.CountTracks(0), false)
            target_track = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
            reaper.GetSetMediaTrackInfo_String(target_track, "P_NAME", "Source Explorer Export", true)
        end
    end
    
    -- Prepare options for region creator
    local options = {
        start_position = start_pos,
        spacing = self.settings.spacing,
        auto_number = self.settings.auto_number,
        start_number = self.settings.start_number,
        include_metadata = self.settings.include_metadata,
        metadata_fields = self.settings.metadata_fields,
        metadata_source = self.settings.metadata_source,  -- Pass metadata source
        target_track = target_track
    }
    
    local success, message
    
    -- Execute based on mode
    if self.settings.insert_items and self.settings.create_regions then
        -- Insert items AND create regions
        success, message = self.region_creator:insertItemsWithRegions(
            self.selected_items, 
            options
        )
    elseif self.settings.create_regions then
        -- Create regions only (assumes items already on timeline)
        success, message = self.region_creator:createRegionsFromItems(
            self.selected_items,
            options
        )
    else
        return false, "No action selected (must insert items or create regions)"
    end
    
    if not success then
        return false, message
    end
    
    -- Configure render settings
    if self.settings.set_render_preset then
        self:configureRenderSettings()
    end
    
    -- Open render dialog if requested
    if self.settings.open_render_dialog then
        reaper.Main_OnCommand(41888, 0)  -- View: Show region render matrix window
    end
    
    return true, message
end

-- Configure REAPER render settings for UCS export
function BatchExport:configureRenderSettings()
    -- Set render pattern (use user's setting or default)
    local render_pattern = self.settings.render_pattern
    if not render_pattern or render_pattern == "" then
        -- Default to extracting category structure from metadata
        render_pattern = "$region(Category)[;]/$region(SubCategory)[;]/$region"
    end
    
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", render_pattern, true)
    
    -- Set render source to Region Render Matrix
    -- RENDER_STEMS bit 8 = Region Render Matrix
    reaper.GetSetProjectInfo_String(0, "RENDER_STEMS", "8", true)
    
    -- Enable metadata embedding (bit 512)
    -- Combined: 8 | 512 = 520
    reaper.GetSetProjectInfo_String(0, "RENDER_STEMS", "520", true)
    
    -- Set up metadata field mappings (iXML)
    self:setupMetadataMapping()
    
    -- Set default render format (WAV, 24-bit) if not already set
    -- This preserves user's format choice if they've set one
    local retval, current_format = reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "", false)
    if not retval or current_format == "" then
        -- Default to WAV 24-bit
        -- Format string: "evaw" (wave) + format flags
        reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "evaw", true)
    end
end

-- Setup metadata field mappings to read from regions or markers
-- This configures REAPER to extract metadata from region/marker names into file metadata
function BatchExport:setupMetadataMapping()
    -- Check REAPER version for marker syntax
    local reaper_version = tonumber(reaper.GetAppVersion():match("%d+%.%d+"))
    local use_semicolon_syntax = (reaper_version >= 6.33)
    
    -- Determine source (region or marker)
    local source_type = self.settings.metadata_source or "region"
    local wildcard_prefix = (source_type == "marker") and "$marker" or "$region"
    
    -- Configure each metadata field
    for metadata_path, field_name in pairs(iXML) do
        -- Special cases for wildcards
        if field_name == "CategoryFull" then
            -- Build from Category-SubCategory
            -- Note: This is a concatenation, might need custom handling
            -- For now, we'll try to use the field directly
            local wildcard = use_semicolon_syntax 
                and string.format("%s(%s)[;]", wildcard_prefix, field_name)
                or string.format("%s(%s)", wildcard_prefix, field_name)
            
            reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", 
                metadata_path .. "|" .. wildcard, true)
        else
            -- Standard field mapping
            -- Format: "IXML:USER:CatID|$region(CatID)[;]" or "$marker(CatID)[;]"
            local wildcard = use_semicolon_syntax 
                and string.format("%s(%s)[;]", wildcard_prefix, field_name)
                or string.format("%s(%s)", wildcard_prefix, field_name)
            
            reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", 
                metadata_path .. "|" .. wildcard, true)
        end
    end
    
    -- Add some additional automated fields
    reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", 
        "IXML:USER:ReleaseDate|$date", true)
    
    reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", 
        "IXML:USER:Embedder|Source Explorer", true)
end

-- ============================================================================
-- UI DRAWING
-- ============================================================================

-- Draw the export dialog
-- @param ctx - ImGui context
-- @return (boolean) - True if export was executed
function BatchExport:draw(ctx)
    if not self.is_open then
        return false
    end
    
    local executed = false
    
    -- Open popup
    if not reaper.ImGui_IsPopupOpen(ctx, "Batch Export to Regions") then
        reaper.ImGui_OpenPopup(ctx, "Batch Export to Regions")
    end
    
    -- Set popup size
    reaper.ImGui_SetNextWindowSize(ctx, 500, 650, reaper.ImGui_Cond_Appearing())
    
    if reaper.ImGui_BeginPopupModal(ctx, "Batch Export to Regions", true) then
        
        -- Show item count
        reaper.ImGui_Text(ctx, string.format("Selected Items: %d", #self.selected_items))
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- VALIDATION WARNING
        -- ====================================================================
        if self.show_validation_warning and not self.user_confirmed then
            self:drawValidationWarning(ctx)
        end
        
        -- ====================================================================
        -- POSITION & SPACING
        -- ====================================================================
        reaper.ImGui_SeparatorText(ctx, "Position & Spacing")
        
        -- Start position
        local pos_labels = {"Edit Cursor", "Project Start"}
        local changed, new_pos = reaper.ImGui_Combo(ctx, "Start Position", 
            self.settings.start_position, table.concat(pos_labels, "\0") .. "\0")
        if changed then
            self.settings.start_position = new_pos
        end
        
        -- Spacing
        changed, self.settings.spacing = reaper.ImGui_SliderDouble(ctx, 
            "Spacing (seconds)", self.settings.spacing, 0.0, 5.0, "%.2f")
        
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- NUMBERING
        -- ====================================================================
        reaper.ImGui_SeparatorText(ctx, "Numbering")
        
        changed, self.settings.auto_number = reaper.ImGui_Checkbox(ctx, 
            "Auto-number regions", self.settings.auto_number)
        
        if self.settings.auto_number then
            reaper.ImGui_SetNextItemWidth(ctx, 100)
            changed, self.settings.start_number = reaper.ImGui_InputInt(ctx,
                "Start Number", self.settings.start_number)
            
            if self.settings.start_number < 1 then
                self.settings.start_number = 1
            end
        end
        
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- METADATA OPTIONS
        -- ====================================================================
        reaper.ImGui_SeparatorText(ctx, "Metadata")
        
        changed, self.settings.include_metadata = reaper.ImGui_Checkbox(ctx,
            "Include UCS metadata in region names", self.settings.include_metadata)
        
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx, 
                "Embeds metadata in region names using REAPER's name=value format\n" ..
                "Example: GUNAuto_Shot 01 CatID=GUNAuto;Category=GUNS;SubCategory=AUTOMATIC\n" ..
                "Use $region(FieldName)[;] in render pattern to extract values")
        end
        
        if self.settings.include_metadata then
            reaper.ImGui_Indent(ctx)
            
            -- Metadata fields selector
            local field_options = {"All Fields", "Core Fields Only"}
            local current_idx = (self.settings.metadata_fields == "all") and 0 or 1
            
            changed, current_idx = reaper.ImGui_Combo(ctx, "Fields to Include",
                current_idx, table.concat(field_options, "\0") .. "\0")
            
            if changed then
                self.settings.metadata_fields = (current_idx == 0) and "all" or "core"
            end
            
            if reaper.ImGui_IsItemHovered(ctx) then
                if current_idx == 0 then
                    reaper.ImGui_SetTooltip(ctx, 
                        "Includes: CatID, Category, SubCategory, FXName,\n" ..
                        "Creator, Source, Keywords, Description, etc.")
                else
                    reaper.ImGui_SetTooltip(ctx,
                        "Includes: CatID, Category, SubCategory,\n" ..
                        "FXName, Creator, Source")
                end
            end
            
            -- Metadata source selector
            local source_options = {"Region Metadata", "Marker Metadata (UCS Standard)"}
            local source_idx = (self.settings.metadata_source == "region") and 0 or 1
            
            changed, source_idx = reaper.ImGui_Combo(ctx, "Metadata Source",
                source_idx, table.concat(source_options, "\0") .. "\0")
            
            if changed then
                self.settings.metadata_source = (source_idx == 0) and "region" or "marker"
            end
            
            if reaper.ImGui_IsItemHovered(ctx) then
                if source_idx == 0 then
                    reaper.ImGui_SetTooltip(ctx,
                        "Store metadata in region names (name=value format)\n" ..
                        "Experimental - may not embed in all file formats")
                else
                    reaper.ImGui_SetTooltip(ctx,
                        "Create markers with metadata (UCS Renaming Tool method)\n" ..
                        "Guaranteed to embed in WAV/MP3/OGG metadata")
                end
            end
            
            reaper.ImGui_Unindent(ctx)
        end
        
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- INSERTION OPTIONS
        -- ====================================================================
        reaper.ImGui_SeparatorText(ctx, "Insertion")
        
        changed, self.settings.insert_items = reaper.ImGui_Checkbox(ctx,
            "Insert items to timeline", self.settings.insert_items)
        
        if self.settings.insert_items then
            reaper.ImGui_Indent(ctx)
            
            local track_options = {"Selected Track", "New Track"}
            changed, self.settings.target_track_mode = reaper.ImGui_Combo(ctx,
                "Target Track", self.settings.target_track_mode,
                table.concat(track_options, "\0") .. "\0")
            
            reaper.ImGui_Unindent(ctx)
        end
        
        changed, self.settings.create_regions = reaper.ImGui_Checkbox(ctx,
            "Create regions", self.settings.create_regions)
        
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- RENDER OPTIONS
        -- ====================================================================
        reaper.ImGui_SeparatorText(ctx, "Render Settings")
        
        changed, self.settings.set_render_preset = reaper.ImGui_Checkbox(ctx,
            "Configure render preset", self.settings.set_render_preset)
        
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx,
                "Sets render source to Region Render Matrix\n" ..
                "and enables metadata embedding")
        end
        
        if self.settings.set_render_preset then
            reaper.ImGui_Indent(ctx)
            
            -- Render pattern
            reaper.ImGui_Text(ctx, "Render Pattern:")
            reaper.ImGui_SetNextItemWidth(ctx, -1)
            changed, self.settings.render_pattern = reaper.ImGui_InputText(ctx,
                "##render_pattern", self.settings.render_pattern)
            
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetTooltip(ctx,
                    "REAPER render pattern with wildcards:\n\n" ..
                    "Examples:\n" ..
                    "$region - Full region name with metadata\n" ..
                    "$region(Category)[;]/$region(SubCategory)[;]/$region - Folders by category\n" ..
                    "$project/$region - Project folder + region name\n" ..
                    "Export/$region - Custom folder + region name\n\n" ..
                    "Use $region(FieldName)[;] to extract metadata values")
            end
            
            reaper.ImGui_Unindent(ctx)
        end
        
        changed, self.settings.open_render_dialog = reaper.ImGui_Checkbox(ctx,
            "Open Region Render Matrix after export", self.settings.open_render_dialog)
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- PREVIEW
        -- ====================================================================
        if #self.selected_items > 0 then
            reaper.ImGui_Text(ctx, "Preview (first region):")
            
            local preview_name = self.region_creator:formatRegionName(
                self.selected_items[1],
                self.settings.start_number,
                {
                    auto_number = self.settings.auto_number,
                    include_metadata = self.settings.include_metadata,
                    metadata_fields = self.settings.metadata_fields
                }
            )
            
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 0xFF1E2533)
            reaper.ImGui_InputTextMultiline(ctx, "##preview", preview_name, -1, 60,
                reaper.ImGui_InputTextFlags_ReadOnly())
            reaper.ImGui_PopStyleColor(ctx)
            
            reaper.ImGui_Spacing(ctx)
        end
        
        -- ====================================================================
        -- ACTION BUTTONS
        -- ====================================================================
        
        local can_export = self.user_confirmed or self.validation_result
        
        if not can_export then
            reaper.ImGui_BeginDisabled(ctx)
        end
        
        if reaper.ImGui_Button(ctx, "Export", 150, 0) then
            local success, message = self:execute()
            
            if success then
                self:close()
                executed = true
            else
                reaper.ShowMessageBox(
                    "Export failed:\n\n" .. message,
                    "Batch Export Error",
                    0
                )
            end
        end
        
        if not can_export then
            reaper.ImGui_EndDisabled(ctx)
        end
        
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, "Cancel", 150, 0) then
            self:close()
        end
        
        reaper.ImGui_EndPopup(ctx)
    else
        self:close()
    end
    
    return executed
end

-- Draw validation warning section
-- @param ctx - ImGui context
function BatchExport:drawValidationWarning(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), 0xFF2A1515)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), 0xFF3333AA)
    
    if reaper.ImGui_BeginChild(ctx, "##validation_warning", -1, 150, 
        reaper.ImGui_ChildFlags_Border()) then
        
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFF4499FF)
        reaper.ImGui_Text(ctx, "⚠️  UCS Metadata Warning")
        reaper.ImGui_PopStyleColor(ctx)
        
        reaper.ImGui_Spacing(ctx)
        
        local summary = self.region_creator:getValidationSummary(self.validation_issues)
        reaper.ImGui_TextWrapped(ctx, summary)
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        if reaper.ImGui_Button(ctx, "Continue Anyway", 150, 0) then
            self.user_confirmed = true
            self.show_validation_warning = false
        end
        
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, "Cancel Export", 150, 0) then
            self:close()
        end
        
        reaper.ImGui_EndChild(ctx)
    end
    
    reaper.ImGui_PopStyleColor(ctx, 2)
    
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
end

-- ============================================================================
-- UTILITY
-- ============================================================================

-- Get current settings
-- @return (table) - Settings table
function BatchExport:getSettings()
    return self.settings
end

-- Set settings
-- @param settings (table) - Settings table
function BatchExport:setSettings(settings)
    for k, v in pairs(settings) do
        if self.settings[k] ~= nil then
            self.settings[k] = v
        end
    end
end

return BatchExport