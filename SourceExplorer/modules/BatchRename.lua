-- BatchRename.lua
-- Batch rename functionality for Source Explorer
-- Provides find/replace, prefix/suffix, sequential, and pattern-based renaming

local BatchRename = {}
BatchRename.__index = BatchRename

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Rename methods enum
BatchRename.METHOD = {
    FIND_REPLACE = 1,
    PREFIX_SUFFIX = 2,
    SEQUENTIAL = 3,
    PATTERN = 4
}

BatchRename.METHOD_NAMES = {
    "Find & Replace",
    "Prefix/Suffix",
    "Sequential Numbering",
    "Pattern Template"
}

-- Preview status
BatchRename.STATUS = {
    OK = "ok",
    UNCHANGED = "unchanged",
    DUPLICATE = "duplicate",
    ERROR = "error"
}

-- ============================================================================
-- CONSTRUCTOR
-- ============================================================================

function BatchRename.new()
    local self = setmetatable({}, BatchRename)
    
    -- Dialog state
    self.is_open = false
    self.items = {}
    self.just_renamed = false
    self.rename_count = 0  -- Track how many were renamed
    
    -- Method selection
    self.current_method = BatchRename.METHOD.FIND_REPLACE
    
    -- Method 1: Find & Replace
    self.find_text = ""
    self.replace_text = ""
    self.case_sensitive = false
    self.use_regex = false
    
    -- Method 2: Prefix/Suffix
    self.prefix = ""
    self.suffix = ""
    self.add_numbering = false
    self.numbering_start = 1
    self.numbering_padding = 2
    
    -- Method 3: Sequential
    self.base_name = "Item"
    self.start_number = 1
    self.padding = 2
    
    -- Method 4: Pattern
    self.pattern = "{name}_{num:02}"
    
    -- Preview cache
    self.preview = {}
    self.preview_dirty = true
    
    return self
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

function BatchRename:open(items)
    self.is_open = true
    self.items = items
    self.preview_dirty = true
    self.just_renamed = false
end

function BatchRename:close()
    self.is_open = false
    self.just_renamed = false
end

function BatchRename:isOpen()
    return self.is_open
end

function BatchRename:wasRenamed()
    return self.just_renamed
end

function BatchRename:clearRenameFlag()
    self.just_renamed = false
end

-- ============================================================================
-- DRAWING - Main
-- ============================================================================

function BatchRename:draw(ctx)
    if not self.is_open then
        return
    end
    
    -- Open modal popup
    if not reaper.ImGui_IsPopupOpen(ctx, 'Batch Rename') then
        reaper.ImGui_OpenPopup(ctx, 'Batch Rename')
    end
    
    -- Draw the dialog
    self:drawDialog(ctx)
end

function BatchRename:drawDialog(ctx)
    reaper.ImGui_SetNextWindowSize(ctx, 700, 500, reaper.ImGui_Cond_FirstUseEver())
    
    local visible, open = reaper.ImGui_BeginPopupModal(ctx, 'Batch Rename', true, 
        reaper.ImGui_WindowFlags_NoCollapse())
    
    if not visible then
        return
    end
    
    if not open then
        self.is_open = false
        reaper.ImGui_EndPopup(ctx)
        return
    end
    
    local item_count = #self.items
    
    -- Header
    reaper.ImGui_Text(ctx, string.format("Batch Rename - %d items selected", item_count))
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- Method selector
    self:drawMethodSelector(ctx)
    
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- Method-specific UI
    self:drawMethodUI(ctx)
    
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- Preview
    self:drawPreview(ctx)
    
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- Buttons
    self:drawButtons(ctx)
    
    reaper.ImGui_EndPopup(ctx)
end

-- ============================================================================
-- DRAWING - Components
-- ============================================================================

function BatchRename:drawMethodSelector(ctx)
    reaper.ImGui_Text(ctx, "Rename Method:")
    reaper.ImGui_SameLine(ctx)
    
    reaper.ImGui_SetNextItemWidth(ctx, 200)
    
    local method_combo = BatchRename.METHOD_NAMES[self.current_method]
    
    if reaper.ImGui_BeginCombo(ctx, "##method", method_combo) then
        for i, name in ipairs(BatchRename.METHOD_NAMES) do
            local is_selected = (self.current_method == i)
            if reaper.ImGui_Selectable(ctx, name, is_selected) then
                if self.current_method ~= i then
                    self.current_method = i
                    self.preview_dirty = true
                end
            end
            
            if is_selected then
                reaper.ImGui_SetItemDefaultFocus(ctx)
            end
        end
        reaper.ImGui_EndCombo(ctx)
    end
end

function BatchRename:drawMethodUI(ctx)
    if self.current_method == BatchRename.METHOD.FIND_REPLACE then
        self:drawFindReplaceUI(ctx)
    elseif self.current_method == BatchRename.METHOD.PREFIX_SUFFIX then
        self:drawPrefixSuffixUI(ctx)
    elseif self.current_method == BatchRename.METHOD.SEQUENTIAL then
        self:drawSequentialUI(ctx)
    elseif self.current_method == BatchRename.METHOD.PATTERN then
        self:drawPatternUI(ctx)
    end
end

function BatchRename:drawFindReplaceUI(ctx)
    -- Find input
    reaper.ImGui_Text(ctx, "Find:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 350)
    local changed1, new_find = reaper.ImGui_InputText(ctx, "##find", self.find_text)
    if changed1 then
        self.find_text = new_find
        self.preview_dirty = true
    end
    
    -- Replace input
    reaper.ImGui_Text(ctx, "Replace:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 350)
    local changed2, new_replace = reaper.ImGui_InputText(ctx, "##replace", self.replace_text)
    if changed2 then
        self.replace_text = new_replace
        self.preview_dirty = true
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- Options
    local changed3, new_case = reaper.ImGui_Checkbox(ctx, "Case sensitive", self.case_sensitive)
    if changed3 then
        self.case_sensitive = new_case
        self.preview_dirty = true
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Match exact case (Drum ≠ drum)")
    end
    
    reaper.ImGui_SameLine(ctx, 0, 20)
    
    local changed4, new_regex = reaper.ImGui_Checkbox(ctx, "Use regex", self.use_regex)
    if changed4 then
        self.use_regex = new_regex
        self.preview_dirty = true
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Use Lua pattern matching\nExample: 'v[0-9]' matches v1, v2, v3...")
    end
    
    -- Help text for regex
    if self.use_regex then
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_TextDisabled(ctx, "Regex patterns: . (any char)  [abc] (any of)  [0-9] (digit)  + (1 or more)  * (0 or more)")
    end
end

function BatchRename:drawPrefixSuffixUI(ctx)
    -- Prefix input
    reaper.ImGui_Text(ctx, "Prefix:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 350)
    local changed1, new_prefix = reaper.ImGui_InputText(ctx, "##prefix", self.prefix)
    if changed1 then
        self.prefix = new_prefix
        self.preview_dirty = true
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Text to add at the beginning\nExample: 'SFX_' → SFX_kick.wav")
    end
    
    -- Suffix input
    reaper.ImGui_Text(ctx, "Suffix:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 350)
    local changed2, new_suffix = reaper.ImGui_InputText(ctx, "##suffix", self.suffix)
    if changed2 then
        self.suffix = new_suffix
        self.preview_dirty = true
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Text to add at the end (before extension)\nExample: '_final' → kick_final.wav")
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- Add numbering option
    local changed3, new_numbering = reaper.ImGui_Checkbox(ctx, "Add numbering", self.add_numbering)
    if changed3 then
        self.add_numbering = new_numbering
        self.preview_dirty = true
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Add sequential numbers to prefix or suffix\nExample: SFX_01_kick.wav, SFX_02_snare.wav")
    end
    
    -- Numbering options (only show if add_numbering is enabled)
    if self.add_numbering then
        reaper.ImGui_Indent(ctx, 20)
        
        -- Start number
        reaper.ImGui_Text(ctx, "Start:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, 100)
        local changed4, new_start = reaper.ImGui_InputInt(ctx, "##start", self.numbering_start)
        if changed4 then
            self.numbering_start = math.max(0, new_start)
            self.preview_dirty = true
        end
        
        reaper.ImGui_SameLine(ctx, 0, 20)
        
        -- Padding
        reaper.ImGui_Text(ctx, "Padding:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, 100)
        local changed5, new_padding = reaper.ImGui_InputInt(ctx, "##padding", self.numbering_padding)
        if changed5 then
            self.numbering_padding = math.max(1, math.min(5, new_padding))
            self.preview_dirty = true
        end
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx, "Number of digits (1-5)\n1=1, 2=01, 3=001, etc.")
        end
        
        reaper.ImGui_Unindent(ctx, 20)
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- Examples
    reaper.ImGui_TextDisabled(ctx, "Examples:")
    if self.add_numbering then
        local sample_num = string.format("%0" .. self.numbering_padding .. "d", self.numbering_start)
        reaper.ImGui_BulletText(ctx, string.format("'%s' + numbering → %s%s_filename.wav", 
            self.prefix, self.prefix, sample_num))
    else
        reaper.ImGui_BulletText(ctx, string.format("'%s' prefix → %sfilename.wav", self.prefix, self.prefix))
        reaper.ImGui_BulletText(ctx, string.format("'%s' suffix → filename%s.wav", self.suffix, self.suffix))
    end
end

function BatchRename:drawSequentialUI(ctx)
    -- Base name input
    reaper.ImGui_Text(ctx, "Base name:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 350)
    local changed1, new_base = reaper.ImGui_InputText(ctx, "##basename", self.base_name)
    if changed1 then
        self.base_name = new_base
        self.preview_dirty = true
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Base name for all files\nExample: 'Track' → Track_01.wav, Track_02.wav")
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- Start number
    reaper.ImGui_Text(ctx, "Start number:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 150)
    local changed2, new_start = reaper.ImGui_InputInt(ctx, "##seqstart", self.start_number)
    if changed2 then
        self.start_number = math.max(0, new_start)
        self.preview_dirty = true
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "First number in sequence")
    end
    
    reaper.ImGui_SameLine(ctx, 0, 20)
    
    -- Padding
    reaper.ImGui_Text(ctx, "Padding:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 150)
    local changed3, new_padding = reaper.ImGui_InputInt(ctx, "##seqpadding", self.padding)
    if changed3 then
        self.padding = math.max(1, math.min(5, new_padding))
        self.preview_dirty = true
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Number of digits (1-5)\n1=1, 2=01, 3=001, etc.")
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- Examples
    reaper.ImGui_TextDisabled(ctx, "Examples:")
    local sample_num1 = string.format("%0" .. self.padding .. "d", self.start_number)
    local sample_num2 = string.format("%0" .. self.padding .. "d", self.start_number + 1)
    reaper.ImGui_BulletText(ctx, string.format("'%s' → %s_%s.wav", self.base_name, self.base_name, sample_num1))
    reaper.ImGui_BulletText(ctx, string.format("(2nd item) → %s_%s.wav", self.base_name, sample_num2))
end

function BatchRename:drawPatternUI(ctx)
    -- Pattern input
    reaper.ImGui_Text(ctx, "Pattern:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_SetNextItemWidth(ctx, 350)
    local changed, new_pattern = reaper.ImGui_InputText(ctx, "##pattern", self.pattern)
    if changed then
        self.pattern = new_pattern
        self.preview_dirty = true
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Use variables to create patterns\nCombine text and variables as needed")
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- Available variables
    reaper.ImGui_TextDisabled(ctx, "Available variables:")
    reaper.ImGui_BulletText(ctx, "{name} - Original filename (without extension)")
    reaper.ImGui_BulletText(ctx, "{num} or {num:02} - Sequential number with optional padding")
    reaper.ImGui_BulletText(ctx, "{index} - Item position (1-based index)")
    reaper.ImGui_BulletText(ctx, "{date} - Current date (YYYY-MM-DD)")
    reaper.ImGui_BulletText(ctx, "{time} - Current time (HHMMSS)")
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Hover over each for details")
    end
    
    reaper.ImGui_Spacing(ctx)
    
    -- Examples
    reaper.ImGui_TextDisabled(ctx, "Examples:")
    reaper.ImGui_BulletText(ctx, "SFX_{name}_{num:03} → SFX_kick_001.wav")
    reaper.ImGui_BulletText(ctx, "{date}_{name} → 2024-12-27_kick.wav")
    reaper.ImGui_BulletText(ctx, "Track_{index:02}_{name} → Track_01_kick.wav")
end

function BatchRename:drawPreview(ctx)
    reaper.ImGui_Text(ctx, "Preview:")
    
    -- Update preview if dirty
    if self.preview_dirty then
        self.preview = self:generatePreview()
        self.preview_dirty = false
    end
    
    -- Draw preview table
    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local preview_height = math.min(200, avail_h - 60)
    
    if reaper.ImGui_BeginChild(ctx, "preview", avail_w, preview_height, 
        reaper.ImGui_ChildFlags_Border()) then
        
        if #self.preview == 0 then
            reaper.ImGui_TextDisabled(ctx, "Preview will appear here...")
        else
            -- Header
            reaper.ImGui_Text(ctx, "OLD NAME")
            reaper.ImGui_SameLine(ctx, 300)
            reaper.ImGui_Text(ctx, "→  NEW NAME")
            reaper.ImGui_Separator(ctx)
            
            -- Preview items
            for i, p in ipairs(self.preview) do
                local color = 0xFFFFFFFF  -- White
                if p.status == BatchRename.STATUS.UNCHANGED then
                    color = 0xFF888888  -- Gray
                elseif p.status == BatchRename.STATUS.DUPLICATE then
                    color = 0xFF4444FF  -- Red
                elseif p.status == BatchRename.STATUS.ERROR then
                    color = 0xFF0000FF  -- Bright red
                end
                
                reaper.ImGui_TextColored(ctx, color, p.old_name)
                reaper.ImGui_SameLine(ctx, 300)
                reaper.ImGui_TextColored(ctx, color, "→  " .. p.new_name)
                
                -- Status icon
                local icon = ""
                if p.status == BatchRename.STATUS.OK then
                    icon = "✓"
                elseif p.status == BatchRename.STATUS.UNCHANGED then
                    icon = "-"
                elseif p.status == BatchRename.STATUS.DUPLICATE then
                    icon = "⚠"
                elseif p.status == BatchRename.STATUS.ERROR then
                    icon = "✗"
                end
                
                reaper.ImGui_SameLine(ctx)
                reaper.ImGui_TextColored(ctx, color, icon)
                
                -- Show error message as tooltip
                if p.error_msg and reaper.ImGui_IsItemHovered(ctx) then
                    reaper.ImGui_SetTooltip(ctx, p.error_msg)
                end
            end
        end
        
        reaper.ImGui_EndChild(ctx)
    end
    
    -- Summary
    local ok_count = 0
    local unchanged_count = 0
    for _, p in ipairs(self.preview) do
        if p.status == BatchRename.STATUS.OK then
            ok_count = ok_count + 1
        elseif p.status == BatchRename.STATUS.UNCHANGED then
            unchanged_count = unchanged_count + 1
        end
    end
    
    reaper.ImGui_Text(ctx, string.format("%d items will be renamed, %d unchanged", 
        ok_count, unchanged_count))
end

function BatchRename:drawButtons(ctx)
    local can_rename = self:canRename()
    
    if not can_rename then
        reaper.ImGui_BeginDisabled(ctx)
    end
    
    if reaper.ImGui_Button(ctx, 'Rename', 120, 0) then
        local success, count = self:applyRename()
        if success then
            self.just_renamed = true
            self.is_open = false
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
    end
    
    if not can_rename then
        reaper.ImGui_EndDisabled(ctx)
    end
    
    reaper.ImGui_SameLine(ctx)
    
    if reaper.ImGui_Button(ctx, 'Cancel', 120, 0) then
        self.is_open = false
        reaper.ImGui_CloseCurrentPopup(ctx)
    end
end

-- ============================================================================
-- PREVIEW GENERATION
-- ============================================================================

function BatchRename:generatePreview()
    if self.current_method == BatchRename.METHOD.FIND_REPLACE then
        return self:previewFindReplace()
    elseif self.current_method == BatchRename.METHOD.PREFIX_SUFFIX then
        return self:previewPrefixSuffix()
    elseif self.current_method == BatchRename.METHOD.SEQUENTIAL then
        return self:previewSequential()
    elseif self.current_method == BatchRename.METHOD.PATTERN then
        return self:previewPattern()
    end
    
    return {}
end

function BatchRename:previewFindReplace()
    local preview = {}
    local regex_error = nil
    
    -- Test regex pattern if enabled
    if self.use_regex and self.find_text ~= "" then
        local test_success, test_result = pcall(function()
            return ("test"):gsub(self.find_text, self.replace_text)
        end)
        
        if not test_success then
            regex_error = "Invalid regex pattern: " .. tostring(test_result)
        end
    end
    
    for _, item in ipairs(self.items) do
        local old_name = item.takeName or ""
        local new_name = old_name
        local status = BatchRename.STATUS.OK
        local error_msg = nil
        
        -- Only process if we have find text
        if self.find_text ~= "" then
            if regex_error then
                -- Regex error - mark all as errors
                new_name = old_name
                status = BatchRename.STATUS.ERROR
                error_msg = regex_error
            else
                -- Perform find/replace
                local find_pattern = self.find_text
                local replace_text = self.replace_text
                
                if self.use_regex then
                    -- Use Lua pattern matching (regex)
                    local success, result = pcall(function()
                        return old_name:gsub(find_pattern, replace_text)
                    end)
                    
                    if success then
                        new_name = result
                    else
                        new_name = old_name
                        status = BatchRename.STATUS.ERROR
                        error_msg = "Regex error"
                    end
                else
                    -- Plain text replacement
                    if self.case_sensitive then
                        -- Case sensitive: use plain gsub
                        -- Escape special pattern characters
                        find_pattern = self:escapePattern(find_pattern)
                        new_name = old_name:gsub(find_pattern, replace_text)
                    else
                        -- Case insensitive: manual search and replace
                        new_name = self:replaceInsensitive(old_name, find_pattern, replace_text)
                    end
                end
            end
        end
        
        -- Check if actually changed
        if new_name == old_name and status ~= BatchRename.STATUS.ERROR then
            status = BatchRename.STATUS.UNCHANGED
        end
        
        -- Validate new name
        if status == BatchRename.STATUS.OK then
            local valid, invalid_char = self:validateFilename(new_name)
            if not valid then
                status = BatchRename.STATUS.ERROR
                error_msg = string.format("Invalid character: %s", invalid_char)
            end
        end
        
        table.insert(preview, {
            old_name = old_name,
            new_name = new_name,
            status = status,
            error_msg = error_msg,
            item = item
        })
    end
    
    -- Check for duplicates
    self:detectDuplicates(preview)
    
    return preview
end

function BatchRename:previewPrefixSuffix()
    local preview = {}
    
    -- Check if we have any changes to make
    local has_changes = self.prefix ~= "" or self.suffix ~= ""
    
    if not has_changes then
        -- No prefix or suffix - all unchanged
        for _, item in ipairs(self.items) do
            local old_name = item.takeName or ""
            table.insert(preview, {
                old_name = old_name,
                new_name = old_name,
                status = BatchRename.STATUS.UNCHANGED,
                item = item
            })
        end
        return preview
    end
    
    -- Generate preview with prefix/suffix
    for i, item in ipairs(self.items) do
        local old_name = item.takeName or ""
        local name_without_ext = self:stripExtension(old_name)
        local ext = self:getExtension(old_name)
        
        local new_name_base = name_without_ext
        local status = BatchRename.STATUS.OK
        local error_msg = nil
        
        -- Add prefix
        if self.prefix ~= "" then
            if self.add_numbering then
                -- Add prefix with number
                local num = self.numbering_start + (i - 1)
                local num_str = string.format("%0" .. self.numbering_padding .. "d", num)
                new_name_base = self.prefix .. num_str .. "_" .. new_name_base
            else
                -- Just add prefix
                new_name_base = self.prefix .. new_name_base
            end
        end
        
        -- Add suffix (before extension)
        if self.suffix ~= "" then
            if self.add_numbering and self.prefix == "" then
                -- Add suffix with number (only if no prefix with numbering)
                local num = self.numbering_start + (i - 1)
                local num_str = string.format("%0" .. self.numbering_padding .. "d", num)
                new_name_base = new_name_base .. "_" .. num_str .. self.suffix
            else
                -- Just add suffix
                new_name_base = new_name_base .. self.suffix
            end
        end
        
        -- Reconstruct with extension
        local new_name = new_name_base
        if ext ~= "" then
            new_name = new_name_base .. "." .. ext
        end
        
        -- Validate new name
        local valid, invalid_char = self:validateFilename(new_name)
        if not valid then
            status = BatchRename.STATUS.ERROR
            error_msg = string.format("Invalid character: %s", invalid_char)
        end
        
        -- Check if actually changed
        if new_name == old_name and status ~= BatchRename.STATUS.ERROR then
            status = BatchRename.STATUS.UNCHANGED
        end
        
        table.insert(preview, {
            old_name = old_name,
            new_name = new_name,
            status = status,
            error_msg = error_msg,
            item = item
        })
    end
    
    -- Check for duplicates
    self:detectDuplicates(preview)
    
    return preview
end

function BatchRename:previewSequential()
    local preview = {}
    
    -- Check if base name is empty
    if self.base_name == "" then
        -- No base name - all unchanged
        for _, item in ipairs(self.items) do
            local old_name = item.takeName or ""
            table.insert(preview, {
                old_name = old_name,
                new_name = old_name,
                status = BatchRename.STATUS.UNCHANGED,
                item = item
            })
        end
        return preview
    end
    
    -- Generate sequential names
    for i, item in ipairs(self.items) do
        local old_name = item.takeName or ""
        local ext = self:getExtension(old_name)
        
        -- Calculate number
        local num = self.start_number + (i - 1)
        local num_str = string.format("%0" .. self.padding .. "d", num)
        
        -- Build new name: basename_number.ext
        local new_name_base = self.base_name .. "_" .. num_str
        local new_name = new_name_base
        if ext ~= "" then
            new_name = new_name_base .. "." .. ext
        end
        
        local status = BatchRename.STATUS.OK
        local error_msg = nil
        
        -- Validate new name
        local valid, invalid_char = self:validateFilename(new_name)
        if not valid then
            status = BatchRename.STATUS.ERROR
            error_msg = string.format("Invalid character: %s", invalid_char)
        end
        
        -- Check if actually changed
        if new_name == old_name and status ~= BatchRename.STATUS.ERROR then
            status = BatchRename.STATUS.UNCHANGED
        end
        
        table.insert(preview, {
            old_name = old_name,
            new_name = new_name,
            status = status,
            error_msg = error_msg,
            item = item
        })
    end
    
    -- Check for duplicates
    self:detectDuplicates(preview)
    
    return preview
end

function BatchRename:previewPattern()
    local preview = {}
    
    -- Check if pattern is empty
    if self.pattern == "" then
        -- No pattern - all unchanged
        for _, item in ipairs(self.items) do
            local old_name = item.takeName or ""
            table.insert(preview, {
                old_name = old_name,
                new_name = old_name,
                status = BatchRename.STATUS.UNCHANGED,
                item = item
            })
        end
        return preview
    end
    
    -- Get current date/time
    local date_str = os.date("%Y-%m-%d")
    local time_str = os.date("%H%M%S")
    
    -- Generate pattern-based names
    for i, item in ipairs(self.items) do
        local old_name = item.takeName or ""
        local name_without_ext = self:stripExtension(old_name)
        local ext = self:getExtension(old_name)
        
        local new_name_base = self.pattern
        local status = BatchRename.STATUS.OK
        local error_msg = nil
        
        -- Replace variables
        -- {name} - Original filename
        new_name_base = new_name_base:gsub("{name}", name_without_ext)
        
        -- {index} - 1-based position
        new_name_base = new_name_base:gsub("{index:(%d+)}", function(padding)
            return string.format("%0" .. padding .. "d", i)
        end)
        new_name_base = new_name_base:gsub("{index}", tostring(i))
        
        -- {num} - Sequential number (uses start_number)
        local num = self.start_number + (i - 1)
        new_name_base = new_name_base:gsub("{num:(%d+)}", function(padding)
            return string.format("%0" .. padding .. "d", num)
        end)
        new_name_base = new_name_base:gsub("{num}", tostring(num))
        
        -- {date} - Current date
        new_name_base = new_name_base:gsub("{date}", date_str)
        
        -- {time} - Current time
        new_name_base = new_name_base:gsub("{time}", time_str)
        
        -- Reconstruct with extension
        local new_name = new_name_base
        if ext ~= "" then
            new_name = new_name_base .. "." .. ext
        end
        
        -- Validate new name
        local valid, invalid_char = self:validateFilename(new_name)
        if not valid then
            status = BatchRename.STATUS.ERROR
            error_msg = string.format("Invalid character: %s", invalid_char)
        end
        
        -- Check if actually changed
        if new_name == old_name and status ~= BatchRename.STATUS.ERROR then
            status = BatchRename.STATUS.UNCHANGED
        end
        
        table.insert(preview, {
            old_name = old_name,
            new_name = new_name,
            status = status,
            error_msg = error_msg,
            item = item
        })
    end
    
    -- Check for duplicates
    self:detectDuplicates(preview)
    
    return preview
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

function BatchRename:detectDuplicates(preview)
    local name_counts = {}
    
    -- Count occurrences
    for _, p in ipairs(preview) do
        if p.status == BatchRename.STATUS.OK then
            name_counts[p.new_name] = (name_counts[p.new_name] or 0) + 1
        end
    end
    
    -- Mark duplicates
    for _, p in ipairs(preview) do
        if name_counts[p.new_name] and name_counts[p.new_name] > 1 then
            p.status = BatchRename.STATUS.DUPLICATE
        end
    end
end

function BatchRename:canRename()
    -- Check if rename button should be enabled
    if #self.preview == 0 then
        return false
    end
    
    -- Check if any items will be renamed
    for _, p in ipairs(self.preview) do
        if p.status == BatchRename.STATUS.OK then
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- APPLY RENAME
-- ============================================================================

function BatchRename:applyRename()
    local count = 0
    
    for _, p in ipairs(self.preview) do
        if p.status == BatchRename.STATUS.OK then
            p.item.takeName = p.new_name
            count = count + 1
        end
    end
    
    -- Store count for success message
    self.rename_count = count
    
    -- Show success message
    if count > 0 then
        reaper.ShowMessageBox(
            string.format("Successfully renamed %d item%s", count, count == 1 and "" or "s"),
            "Rename Complete",
            0
        )
    end
    
    return true, count
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function BatchRename:stripExtension(filename)
    return filename:match("(.+)%..+$") or filename
end

function BatchRename:getExtension(filename)
    return filename:match("%.([^%.]+)$") or ""
end

function BatchRename:validateFilename(name)
    -- Check for invalid characters: / \ : * ? " < > |
    local invalid = name:match('[/\\:*?"<>|]')
    return invalid == nil, invalid
end

-- Escape special Lua pattern characters for literal matching
function BatchRename:escapePattern(text)
    -- Escape magic characters: ^$()%.[]*+-?
    return text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-- Case-insensitive string replacement
function BatchRename:replaceInsensitive(str, find, replace)
    if find == "" then
        return str
    end
    
    local lower_str = str:lower()
    local lower_find = find:lower()
    local result = str
    local offset = 0
    
    while true do
        local start_pos, end_pos = lower_str:find(lower_find, offset + 1, true)
        if not start_pos then
            break
        end
        
        -- Replace this occurrence
        local before = result:sub(1, start_pos - 1)
        local after = result:sub(end_pos + 1)
        result = before .. replace .. after
        
        -- Update lower_str and offset for next search
        lower_str = result:lower()
        offset = start_pos + #replace - 1
    end
    
    return result
end

return BatchRename