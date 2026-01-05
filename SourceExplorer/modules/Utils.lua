local Utils = {}

function Utils.Msg(param, debug)
    if debug then
        reaper.ShowConsoleMsg(tostring(param) .. "\n")
    end
end

-- Get filename from full path
function Utils.GetFileNameFromPath(path)
    if not path then return "" end
    return path:match("([^/\\]+)$") or path
end

function Utils.GetItemPropertiesFromChunk(chunk)
    if not chunk then return nil end

    -- Source offset and length
    local soffs = chunk:match("SOFFS ([%d%.%-]+)")
    local source_offset = tonumber(soffs) or 0

    local len = chunk:match("LENGTH ([%d%.%-]+)")
    local item_length = tonumber(len) or 0
    
    -- Playback rate
    local rate_match = chunk:match("PLAYRATE ([%d%.%-]+)")
    local playback_rate = tonumber(rate_match) or 1.0
    
    -- Preserve pitch (0 = don't preserve, 1 = preserve)
    local preserve_pitch_match = chunk:match("PLAYRATE [%d%.]+ ([01])")
    local preserve_pitch = tonumber(preserve_pitch_match) or 0
    
    -- Fade in length - second number is the length
    local fadein_match = chunk:match("FADEIN [%d%.]+ ([%d%.%-]+)")
    local fade_in = tonumber(fadein_match) or 0
    
    -- Fade out length - second number is the length  
    local fadeout_match = chunk:match("FADEOUT [%d%.]+ ([%d%.%-]+)")
    local fade_out = tonumber(fadeout_match) or 0
    
    -- Volume
    local vol_match = chunk:match("VOLPAN ([%d%.%-]+)")
    local volume = tonumber(vol_match) or 1.0
    
    return {
        source_offset = source_offset,
        item_length = item_length,
        playback_rate = playback_rate,
        preserve_pitch = preserve_pitch == 1,
        fade_in = fade_in,
        fade_out = fade_out,
        volume = volume
    }
end

-- Extract source start offset from item chunk (simplified version)
function Utils.GetSourceOffsetFromChunk(chunk)
    if not chunk then return 0, nil end
    
    local soffs = chunk:match("SOFFS ([%d%.%-]+)")
    local source_offset = tonumber(soffs) or 0
    
    local len = chunk:match("LENGTH ([%d%.%-]+)")
    local item_length = tonumber(len) or 0
    
    return source_offset, item_length
end

-- Execute a REAPER named command
function Utils.ReaperNamedCommand(command)
    reaper.Main_OnCommand(reaper.NamedCommandLookup(command), 0)
end

-- Check if SWS extension is installed
function Utils.CheckSWSInstalled()
    if not reaper.CF_CreatePreview then
        reaper.ShowMessageBox(
            "This script requires the SWS Extension.\n\n" ..
            "Please install it from:\n" ..
            "https://www.sws-extension.org/",
            "SWS Extension Required",
            0
        )
        return false
    end
    return true
end

function Utils.split(str, sep)
    local result = {}
    for match in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(result, match)
    end
    return result
end

-- ============================================================================
-- DIALOG HELPERS
-- ============================================================================

-- Show a Yes/No confirmation dialog
-- Returns: true if user clicked Yes, false if No
function Utils.Confirm(message, title)
    title = title or "Confirm"
    local return_value = reaper.ShowMessageBox(message, title, 4) -- 4 = yes/no
    return return_value == 6 -- 6 = yes
end

-- Show an alert/info message
function Utils.Alert(message, title)
    title = title or "Source Explorer"
    reaper.ShowMessageBox(message, title, 0)  -- 0 = OK only
end


-- Show a Yes/No/Cancel dialog
-- Returns: "yes", "no", or "cancel"
function Utils.YesNoCancel(message, title)
    title = title or "Confirm"
    local return_value = reaper.ShowMessageBox(message, title, 3)  -- 3 = Yes/No/Cancel
    
    if return_value == 6 then
        return "yes"
    elseif return_value == 7 then
        return "no"
    else
        return "cancel"
    end
end

-- ============================================================================
-- STRING UTILITIES
-- ============================================================================

-- Trim whitespace from both ends of a string
function Utils.Trim(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$")
end


-- Parse a pattern template with variable substitution
-- Example: ParsePattern("{name}_{num:03}", {name="Shot", num=5}) → "Shot_005"
function Utils.ParsePattern(pattern, variables)
    if not pattern then return "" end
    if not variables then return pattern end
    
    local result = pattern
    
    for key, value in pairs(variables) do
        -- Handle formatted numbers like {num:03}
        local formatted_pattern = "{" .. key .. ":(%d+)}"
        local format_match = result:match(formatted_pattern)
        
        if format_match then
            local width = tonumber(format_match)
            local formatted_value = string.format("%0" .. width .. "d", value)
            result = result:gsub(formatted_pattern, formatted_value)
        else
            -- Simple substitution {key}
            local simple_pattern = "{" .. key .. "}"
            result = result:gsub(simple_pattern, tostring(value))
        end
    end
    
    return result
end

-- Apply find and replace to text
function Utils.ApplyFindReplace(text, find_text, replace_text, case_sensitive, use_regex)
    if not text or find_text == "" then return text end
    
    replace_text = replace_text or ""
    
    if use_regex then
        -- Use Lua pattern matching
        local success, result = pcall(function()
            return text:gsub(find_text, replace_text)
        end)
        
        if success then
            return result
        else
            -- Pattern error, return original
            return text
        end
    else
        -- Plain text find/replace
        if not case_sensitive then
            -- Case-insensitive search
            local find_lower = find_text:lower()
            local text_lower = text:lower()
            local start_pos = 1
            local result = text
            
            while true do
                local find_start, find_end = text_lower:find(find_lower, start_pos, true)
                if not find_start then break end
                
                result = result:sub(1, find_start - 1) .. replace_text .. result:sub(find_end + 1)
                
                -- Adjust for length change
                local length_diff = #replace_text - (find_end - find_start + 1)
                text_lower = text_lower:sub(1, find_start - 1) .. replace_text:lower() .. text_lower:sub(find_end + 1)
                start_pos = find_start + #replace_text
            end
            
            return result
        else
            -- Case-sensitive plain text replace
            return text:gsub(find_text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1"), replace_text)
        end
    end
end

-- ============================================================================
-- COLLECTION UTILITIES
-- ============================================================================

-- Convert array of items (with :toTable() method) to array of tables
function Utils.ItemsToTables(items)
    if not items then return {} end
    
    local tables = {}
    for i, item in ipairs(items) do
        if item.toTable then
            tables[i] = item:toTable()
        else
            tables[i] = item  -- Already a table
        end
    end
    
    return tables
end

-- Filter items based on a predicate function
-- predicate(item, index) should return true to keep the item
function Utils.FilterItems(items, predicate)
    if not items then return {} end
    if not predicate then return items end
    
    local filtered = {}
    for index, item in ipairs(items) do
        if predicate(item, index) then
            table.insert(filtered, item)
        end
    end
    
    return filtered
end

-- Transform items using a mapping function
-- transform_fn(item, index) should return the transformed item
function Utils.MapItems(items, transform_fn)
    if not items then return {} end
    if not transform_fn then return items end
    
    local mapped = {}
    for index, item in ipairs(items) do
        mapped[index] = transform_fn(item, index)
    end
    
    return mapped
end

-- Find first item matching predicate
function Utils.FindItem(items, predicate)
    if not items or not predicate then return nil end
    
    for index, item in ipairs(items) do
        if predicate(item, index) then
            return item, index
        end
    end
    
    return nil
end

-- ============================================================================
-- BATCH PROCESSING
-- ============================================================================

-- Process items in a batch with undo/redo support
-- process_fn(item, index) should return true on success
-- Returns: success_count, total_count
function Utils.BatchProcess(items, process_fn, undo_name)
    if not items or not process_fn then 
        return 0, 0 
    end
    
    undo_name = undo_name or "Batch Process"
    local total_count = #items
    local success_count = 0
    
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
    
    for index, item in ipairs(items) do
        local success = process_fn(item, index)
        if success then
            success_count = success_count + 1
        end
    end
    
    reaper.Undo_EndBlock(undo_name, -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    
    return success_count, total_count
end

-- ============================================================================
-- TREE RENDERING HELPERS
-- ============================================================================

-- Draw a tree node with icon, color, and selection state
-- Returns: clicked, toggled (toggled = expand/collapse was clicked)
function Utils.DrawTreeNode(ctx, label, icon, color, is_selected, is_open)
    local tree_node_flags = reaper.ImGui_TreeNodeFlags_SpanFullWidth()
    
    if is_selected then
        tree_node_flags = tree_node_flags | reaper.ImGui_TreeNodeFlags_Selected()
    end
    
    if not is_open then
        tree_node_flags = tree_node_flags | reaper.ImGui_TreeNodeFlags_DefaultOpen()
    end
    
    -- Apply color if provided
    local color_pushed = false
    if color then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), color)
        color_pushed = true
    end
    
    -- Draw node with icon
    local display_label = icon and (icon .. " " .. label) or label
    local is_node_open = reaper.ImGui_TreeNodeEx(ctx, display_label, tree_node_flags)
    
    if color_pushed then
        reaper.ImGui_PopStyleColor(ctx, 1)
    end
    
    -- Check if node was clicked
    local clicked = reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left())
    local toggled = reaper.ImGui_IsItemToggledOpen(ctx)
    
    return is_node_open, clicked, toggled
end

-- Draw indentation for tree hierarchy
function Utils.DrawTreeIndent(ctx, indent_level)
    if indent_level and indent_level > 0 then
        reaper.ImGui_Indent(ctx, indent_level * 20)  -- 20 pixels per level
    end
end

-- ============================================================================
-- UCS VALIDATION (NIL-SAFE WRAPPER)
-- ============================================================================

-- Validate UCS metadata with nil-safety
-- Returns: is_valid, missing_fields (array of field names)
function Utils.ValidateUCSMetadata(ucs)
    if not ucs then 
        return false, {"No UCS metadata"}
    end
    
    -- Call the UCSMetadata validation method
    if ucs.isComplete then
        local is_complete, missing_field_name = ucs:isComplete()
        if not is_complete then
            return false, ucs:getMissingFields()
        end
        return true, {}
    end
    
    -- Fallback if methods don't exist
    return false, {"Invalid UCS object"}
end

return Utils