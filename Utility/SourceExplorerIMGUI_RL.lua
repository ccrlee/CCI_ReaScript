--[[ 
description: Source Explorer for managing large amounts of sound design source
author: Roc Lee
version: 0.2
changelog:
    0.2
    # Import Export ability, save to project, double click to insert
    0.1
    # Store items from project
--]]

local VSDEBUG = dofile("c:/Users/ccuts/.vscode/extensions/antoinebalaine.reascript-docs-0.1.16/debugger/LoadDebug.lua")
local script_name = 'SourceExplorerRL'
local saved_info = 'storedClips'

function ReaperNamedCommand(command)
    reaper.Main_OnCommand(reaper.NamedCommandLookup(command), 0)
end

function GetFileNameFromPath(path)
    if not path then return "" end
    return path:match("([^/\\]+)$") or path
end

-- Serializer
function SaveTableToProject(table_data)
    local tbl_string = TableToString(table_data)  -- Convert table to JSON string

    reaper.SetProjExtState(0, script_name, saved_info, tbl_string)
    return tbl_string
end

-- Load the table from ProjectExtState
function LoadTableFromProject(script_name, key)
    local retval, tbl_string = reaper.GetProjExtState(0, script_name, key)
    if retval > 0 and tbl_string ~= "" then
        return StringToTable(tbl_string)
    end
    return nil
end

-- Table approach
function TableToString(tbl)
    local function serialize(val, depth)
        depth = depth or 0
        local indent = string.rep("  ", depth)
        local t = type(val)
        
        if t == "table" then
            local result = "{\n"
            for k, v in pairs(val) do
                result = result .. indent .. "  "
                
                -- Handle key
                if type(k) == "number" then
                    result = result .. "[" .. k .. "] = "
                else
                    result = result .. "[" .. string.format("%q", k) .. "] = "
                end
                
                -- Handle value
                result = result .. serialize(v, depth + 1) .. ",\n"
            end
            result = result .. indent .. "}"
            return result
        elseif t == "string" then
            return string.format("%q", val)
        elseif t == "number" or t == "boolean" then
            return tostring(val)
        else
            return "nil"
        end
    end
    
    return serialize(tbl)
end

-- Deserialize string back to table
function StringToTable(str)
    if not str or str == "" then return nil end
    
    local func, err = load("return " .. str)
    if not func then
        reaper.ShowConsoleMsg("Error loading: " .. tostring(err) .. "\n")
        return nil
    end
    
    local success, result = pcall(func)
    if not success then
        reaper.ShowConsoleMsg("Error executing: " .. tostring(result) .. "\n")
        return nil
    end
    
    return result
end

function ImportData(targetTbl)
    local num, files = reaper.JS_Dialog_BrowseForOpenFiles('Open Data', reaper.GetProjectPath(), '', "Lua script files\0*.lua\0", false)
    -- Msg(files)
    file = io.open(files, 'r')
    if file == nil then return end

    local data = file:read("a")
    file:close()
    -- Msg(data)

    local newTable = StringToTable(data)

    for k, v in pairs(newTable) do
        table.insert(targetTbl, v)
    end


end
----- AUDIO ITEM FROM CLAUDE DEF

-- audio_item.lua module
local AudioItem = {}

-- Private default values
local defaults = {
    file = -1,
    takeName = -1,
    index = -1,
    chunk = -1,
    item = -1
}
-- itemNames[i] = { file = fileName, take = takename, index = itemIndex, selected = false , chunk = pulledChunk}

-- Constructor
function AudioItem.new(config)
    config = config or {}
    
    local instance = {}

    -- Apply defaults, then overrides
    for k, v in pairs(defaults) do  ------- for loop not working
        -- Msg(config[k])
        instance[k] = config[k] or v
        -- Msg(instance[key])
    end
    -- Msg('test2')
    -- Add methods
    -- instance.get_duration = function(self)
    --     return self.end_time - self.start_time
    -- end
    
    -- instance.is_valid = function(self)
    --     return self.path ~= nil
    -- end
    
    return instance
end

-- Usage
-- local audio1 = AudioItem.new({path = "song.wav", end_time = 120})
-- local audio2 = AudioItem.new() -- All defaults

-----
local debug = true

function Msg (param)
    if debug then
      reaper.ShowConsoleMsg(tostring (param).."\n")
    end
end

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

-- Init ImGui context
local ctx = reaper.ImGui_CreateContext('Source Explorer', reaper.ImGui_ConfigFlags_None())
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.2'
-- State variable
local show_message = false
local markedForDelete = -1


function GetAllItems()
    -- local itemCount = reaper.CountMediaItems(0)
    local itemNames = {}

    local itemCount = reaper.CountSelectedMediaItems(0)

    -- if itemCount < 1 do return nil

    for i = 0, itemCount - 1 do
        -- Msg(i)
        local item = reaper.GetSelectedMediaItem(0, i)
        local itemIndex = ultraschall.GetItem_Number(item)
        -- Msg('item index: ' .. itemIndex)
        local take = reaper.GetMediaItemTake(item, 0)
        local source = reaper.GetMediaItemTake_Source(take)
        local fileName = reaper.GetMediaSourceFileName(source)
        local _, pulledChunk = reaper.GetItemStateChunk(item, 'pulledChunk') 

        local _, takename = reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', 'takename', false)

        if fileName ~= '' then
            -- Msg(fileName)
            itemNames[i+1] = { file = fileName, take = takename, tk = take, index = itemIndex, selected = false , chunk = pulledChunk, item = item}
            -- Msg(itemNames[i].file)
        end
    end

    return itemNames
end

-------------
---
function DrawWaveform(ctx, tbl, selectedRow, height)
    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    
    -- reaper.ImGui_BeginChild(ctx, 'WaveformSection', avail_w, avail_h)
    reaper.ImGui_BeginChild(ctx, 'WaveformSection', avail_w, avail_h, reaper.ImGui_ChildFlags_None())

    if selectedRow > 0 then
        if tbl[selectedRow] == nil then return end

        local selected = tbl[selectedRow]
        
        -- Display info
        local filename = selected.file:match("([^\\]+)$") or selected.file
        reaper.ImGui_Text(ctx, "Waveform: " .. filename)
        
        -- Get draw list for custom drawing
        local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
        local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
        local w = reaper.ImGui_GetContentRegionAvail(ctx)
        local h = height - 30  -- Leave space for text
        
        -- Draw background
        reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, 0xFF1A1A1A)
        
        -- Draw waveform placeholder (you'll need to implement actual waveform drawing)
        -- DrawWaveformData(draw_list, x, y, w, h, selected)
        DrawWaveformFromFile(draw_list, x, y, w, h, selected.file, selected.take)
    else
        reaper.ImGui_TextColored(ctx, reaper.ImGui_Col_ButtonHovered(), "No item selected")
    end
    
    reaper.ImGui_EndChild(ctx)
end

-- Function to actually draw waveform data
function DrawWaveformData(draw_list, x, y, width, height, item_data)
    -- This is a placeholder - actual waveform drawing requires:
    -- 1. Loading audio file data
    -- 2. Analyzing peaks/samples
    -- 3. Drawing line segments
    
    -- For now, draw a simple representation
    local center_y = y + height / 2
    local color = 0xFF00FF00  -- Green
    
    -- Draw center line
    reaper.ImGui_DrawList_AddLine(draw_list, x, center_y, x + width, center_y, 0xFF444444, 1)
    
    -- Draw simple waveform simulation
    for i = 0, width, 2 do
        local sample = math.sin(i * 0.05) * (height * 0.3)
        reaper.ImGui_DrawList_AddLine(draw_list, 
            x + i, center_y - sample, 
            x + i, center_y + sample, 
            color, 1)
    end
    
    -- You could also get actual PCM peaks from the source:
    -- local source = reaper.PCM_Source_CreateFromFile(item_data.file)
    -- Then read peaks and draw them
end

function DrawWaveformFromFile(draw_list, x, y, width, height, filepath, take)
    local source = reaper.PCM_Source_CreateFromFile(filepath)
    if not source then
        reaper.ImGui_DrawList_AddText(draw_list, x + 10, y + height/2, 0xFFFF0000, "Could not load audio")
        return
    end
    
    -- Must create accessor from source
    local accessor = reaper.CreateTakeAudioAccessor(take)
    if not accessor then
        reaper.PCM_Source_Destroy(source)
        reaper.ImGui_DrawList_AddText(draw_list, x + 10, y + height/2, 0xFFFF0000, "Could not create accessor")
        return
    end
    
    local length = reaper.GetMediaSourceLength(source)
    local sample_rate = reaper.GetMediaSourceSampleRate(source)
    local num_channels = reaper.GetMediaSourceNumChannels(source)
    
    local center_y = y + height / 2
    local half_height = height * 0.4
    
    -- Draw center line
    reaper.ImGui_DrawList_AddLine(draw_list, x, center_y, x + width, center_y, 0xFF444444, 1)
    
    -- Samples to read per pixel
    local samples_per_pixel = 512
    local buffer = reaper.new_array(samples_per_pixel * num_channels)
    
    -- Draw waveform
    for pixel = 0, width - 1 do
        local start_time = (pixel / width) * length
        
        -- Read samples
        local samples_read = reaper.GetAudioAccessorSamples(
            accessor,
            sample_rate,
            num_channels,
            start_time,
            samples_per_pixel,
            buffer
        )
        
        local peak_min = 0
        local peak_max = 0
        
        -- Find peaks - check every sample
        if samples_read > 0 then
            for i = 1, samples_read do
                -- Get first channel (mono or left)
                local sample = buffer[(i-1) * num_channels + 1]
                if sample then
                    peak_min = math.min(peak_min, sample)
                    peak_max = math.max(peak_max, sample)
                end
            end
        end
        
        -- Draw the line
        local y_top = center_y - (peak_max * half_height)
        local y_bottom = center_y - (peak_min * half_height)
        
        reaper.ImGui_DrawList_AddLine(
            draw_list,
            x + pixel, y_top,
            x + pixel, y_bottom,
            0xFF00FF00,
            1
        )
        
        -- Debug first few
        if pixel < 3 then
            Msg(string.format("Pixel %d: read %d samples, min=%.3f max=%.3f", 
                pixel, samples_read, peak_min, peak_max))
        end
    end
    
    reaper.DestroyAudioAccessor(accessor)
    reaper.PCM_Source_Destroy(source)
    Msg('hi')
end
----------------------------------------------------------


local flag = {}
local current_selected = -1
local current_selected1 = -1


local selectedItems = {}
local capturedItems = {}
function CaptureSelection(selection, outTable, shouldDelete)

    Msg(tostring(#selection))

    for i, v in pairs(selection) do
        -- Msg('assignemnt:' .. v.index)

        local config = {
            file = v.file,
            takeName = v.take,
            index = v.index,
            chunk = v.chunk,
            item = v.item
        }

        local audioItem = AudioItem.new(config)
        
        table.insert(outTable, audioItem)

        --DELETE ITEM / TEMP DISABLE
        if shouldDelete then
            
            reaper.PreventUIRefresh(1)
    
            local retval, _ = ultraschall.DeleteMediaItem(selection[i].item)
    
            reaper.PreventUIRefresh(-1)
            reaper.UpdateArrange()
        end
        
    end

    current_selected = -1
    -- selection = {}
    -- return selection
end

local loadData = LoadTableFromProject(script_name, saved_info)

if loadData ~= nil then
    selectedItems = loadData
end

function DeleteEntryFromTable(tbl, entry)
    -- local newTable = {}
    -- if markedForDelete > 0 then
    --     Msg('delete!')
    --     for row = 1, #selectedItems do
    --         if row ~= markedForDelete then
    --             table.insert(newTable, selectedItems[row])
    --         end
    --     end
    --     markedForDelete = -1
    --     current_selected1 = -1
    -- end
    -- selectedItems = newTable
    table.remove(tbl, entry)
    markedForDelete = -1
    current_selected1 = -1
end

function InsertItem(item)
    if item then
        reaper.PreventUIRefresh(1)

        local newItem = reaper.AddMediaItemToTrack(reaper.GetSelectedTrack(0,0))
        reaper.SetItemStateChunk(newItem, item.chunk, true)
        reaper.SetMediaItemPosition(newItem, reaper.GetCursorPosition(), false)
        reaper.PreventUIRefresh(-1)
    end
end

local show_popup = false
-- Main loop function
function main()
    local allTakenames = GetAllItems()

    if markedForDelete > 0 then
        DeleteEntryFromTable(selectedItems, markedForDelete)
    end

    reaper.ImGui_SetNextWindowSize(ctx, 300, 100, reaper.ImGui_Cond_FirstUseEver())
 
    local visible, open = reaper.ImGui_Begin(ctx, 'Source Explorer', true, reaper.ImGui_WindowFlags_HorizontalScrollbar())

    if visible then
        
        reaper.ImGui_BeginGroup(ctx)
        
        if reaper.ImGui_Button(ctx, 'Insert') then
            -- show_message = true

            -- if selectedItems[current_selected1] then
            --     reaper.PreventUIRefresh(1)

            --     local newItem = reaper.AddMediaItemToTrack(reaper.GetSelectedTrack(0,0))
            --     reaper.SetItemStateChunk(newItem, selectedItems[current_selected1].chunk, true)
            --     reaper.SetMediaItemPosition(newItem, reaper.GetCursorPosition(), false)
            --     reaper.PreventUIRefresh(-1)
            -- end
            InsertItem(selectedItems[current_selected1])

            if current_selected == -1 then goto continue end

            local newItem = reaper.AddMediaItemToTrack(reaper.GetSelectedTrack(0,0))
            reaper.SetItemStateChunk(newItem, allTakenames[current_selected].chunk, true)
        end

        ::continue::

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, 'capture selection') then
            -- print(#allTakenames)
            local ctrl = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())

            CaptureSelection(allTakenames, capturedItems, ctrl)

            for key, value in pairs(capturedItems) do
                table.insert(selectedItems, value)
            end

            local json = SaveTableToProject(selectedItems)
            -- Msg(json)
            -- Msg(TableToString(capturedItems)..'length: '..tostring(#capturedItems))
            capturedItems = {}
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, 'Import Data') then
            ImportData(selectedItems)
        end

        reaper.ImGui_SameLine(ctx)

        if reaper.ImGui_Button(ctx, 'Clear') then
            selectedItems = {}
        end

        reaper.ImGui_SameLine(ctx)
        local contentRegionWidth = reaper.ImGui_GetWindowWidth(ctx)

        reaper.ImGui_SetCursorPosX(ctx, contentRegionWidth - 100);

        if reaper.ImGui_Button(ctx, 'Export') then

            if #selectedItems == 0 then return end

            local outputStr = TableToString(selectedItems)

            local projectPath = reaper.GetProjectPath()
            local dir = nil
            if projectPath ~= "" then dir = projectPath
            else reaper.ShowMessageBox("Project is not saved!", "Script Error", 0) return false end
            
            local file = io.open(projectPath..'/CapturedSource.lua', 'w')
            if not file then return false end
            file:write(outputStr)
            file:close()

            show_popup = true
            reaper.ImGui_OpenPopup(ctx, 'File Exported')
        end

            if reaper.ImGui_BeginPopupModal(ctx, 'File Exported', true) then
                reaper.ImGui_Text(ctx, 'File exported to projectPath')
                reaper.ImGui_Separator(ctx)
                
                if reaper.ImGui_Button(ctx, 'OK', 120, 0) then
                    reaper.ImGui_CloseCurrentPopup(ctx)
                    show_popup = false
                end
                
                reaper.ImGui_EndPopup(ctx)
            end

        reaper.ImGui_SameLine(ctx)

        local contentRegionWidth = reaper.ImGui_GetWindowWidth(ctx)

        reaper.ImGui_SetCursorPosX(ctx, contentRegionWidth - 50);


        if reaper.ImGui_Button(ctx, 'Save') then
            SaveTableToProject(selectedItems)
        end

        reaper.ImGui_EndGroup(ctx)
        -- if show_message then
        --     reaper.ImGui_Text(ctx, 'Hello from ImGui!')
        -- end
        
        reaper.ImGui_Separator(ctx)
        local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
        local waveformarea = 0 -- avail_h - 150 - 10
        -- hardcoded space for wave form
        reaper.ImGui_BeginChild(ctx, 'ScrollableContent', avail_w, waveformarea, reaper.ImGui_ChildFlags_None())
-- Captured Table
-- TABLE
    ImGui.BeginTable(ctx,'capture table',3,reaper.ImGui_TableFlags_Resizable() | reaper.ImGui_SelectableFlags_SpanAllColumns() | reaper.ImGui_TableFlags_SizingFixedFit(), reaper.ImGui_GetContentRegionAvail(ctx), 0)
        reaper.ImGui_TableSetupColumn(ctx, 'Index', 20)
        reaper.ImGui_TableSetupColumn(ctx, 'File', reaper.ImGui_TableColumnFlags_WidthStretch())
        reaper.ImGui_TableSetupColumn(ctx, 'Take Name', reaper.ImGui_TableColumnFlags_WidthStretch())
    -- rv, flag = reaper.ImGui_Selectable(ctx, 'test table', flag, reaper.ImGui_SelectableFlags_SpanAllColumns())
    -- ('Row %d'):format(row)

        for row = 1, #selectedItems do
            if selectedItems[row] then    
                
                ImGui.TableNextRow(ctx)
                ImGui.TableNextColumn(ctx)

                local is_selected = row == current_selected1
                local rv, new_selected = reaper.ImGui_Selectable(ctx, '##'..tostring(row)..selectedItems[row]['index'], is_selected, reaper.ImGui_SelectableFlags_SpanAllColumns())
                
                -- Check for double-click on this item
                if reaper.ImGui_IsItemHovered(ctx) and 
                reaper.ImGui_IsMouseDoubleClicked(ctx, reaper.ImGui_MouseButton_Left()) then
                    -- Double-click action - e.g., insert item
                    -- Msg("Double-clicked row " .. row)
                    
                    -- Insert the item
                    InsertItem(selectedItems[row])
                end


                local isDelete = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt())

                if isDelete and rv then
                    markedForDelete = row
                    isDelete = false
                    Msg(markedForDelete)
                end

                reaper.ImGui_SameLine(ctx)
                ImGui.Text(ctx, selectedItems[row]['index'])

                if rv then
                    current_selected1 = row -- super cool, store the selected index outside, and if clicked, set current row as selected index, then ternary assignment to check true false for selecetd each cycle
                end
                
                reaper.ImGui_SameLine(ctx)
                ImGui.TableNextColumn(ctx)
                -- Msg('filename' .. selectedItems[row].file)
                ImGui.Text(ctx, GetFileNameFromPath(selectedItems[row].file))
                ImGui.TableNextColumn(ctx)
                ImGui.Text(ctx, selectedItems[row].takeName)

                reaper.ImGui_SameLine(ctx)

                if reaper.ImGui_Button(ctx, '-') then
                    
                end


            end
        end
    ImGui.EndTable(ctx)

    reaper.ImGui_Separator(ctx)

-- TABLE
    ImGui.BeginTable(ctx,'test table',3,reaper.ImGui_TableFlags_Resizable() | reaper.ImGui_TableFlags_SizingFixedFit(), reaper.ImGui_GetContentRegionAvail(ctx), 0) -- | reaper.ImGui_SelectableFlags_SpanAllColumns())
    
    reaper.ImGui_TableSetupColumn(ctx, 'Index', reaper.ImGui_TableColumnFlags_WidthFixed())
    reaper.ImGui_TableSetupColumn(ctx, 'File', reaper.ImGui_TableColumnFlags_WidthStretch())
    reaper.ImGui_TableSetupColumn(ctx, 'Take Name', reaper.ImGui_TableColumnFlags_WidthStretch())
    -- rv, flag = reaper.ImGui_Selectable(ctx, 'test table', flag, reaper.ImGui_SelectableFlags_SpanAllColumns())
    -- ('Row %d'):format(row)
         for row = 1, #allTakenames do
        
            if allTakenames[row] then    
                
                ImGui.TableNextRow(ctx)
                ImGui.TableNextColumn(ctx)

                local is_selected = row == current_selected
                local rv, new_selected = reaper.ImGui_Selectable(ctx, allTakenames[row].index, is_selected, reaper.ImGui_SelectableFlags_SpanAllColumns() | reaper.ImGui_SelectableFlags_AllowOverlap())
                
                if rv then
                    current_selected = row -- super cool, store the selected index outside, and if clicked, set current row as selected index, then ternary assignment to check true false for selecetd each cycle
                
                    if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
                        -- ReaperNamedCommand(40289) -- deselect all items
                        -- reaper.SetMediaItemSelected(allTakenames[row].item, true)
                        -- ReaperNamedCommand('_SWS_HZOOMITEMS') -- horizontal zoom to selected
                        -- ReaperNamedCommand(40290) -- time selection to items

                        local startTime = reaper.GetMediaItemInfo_Value(allTakenames[row].item, 'D_POSITION')
                        local length = reaper.GetMediaItemInfo_Value(allTakenames[row].item, 'D_LENGTH')
                        reaper.GetSet_LoopTimeRange(true, true, startTime, startTime + length, true)
                        ReaperNamedCommand(40031)
                    end
                end
                
                -- reaper.ImGui_SameLine(ctx)
                ImGui.TableNextColumn(ctx)
                ImGui.Text(ctx, GetFileNameFromPath(allTakenames[row].file))
                ImGui.TableNextColumn(ctx)
                reaper.ImGui_SetNextItemWidth(ctx, -1)
                reaper.ImGui_SetNextItemAllowOverlap(ctx)
                local inputted, returnTake = reaper.ImGui_InputText(ctx, '##take'..tostring(row), allTakenames[row].take)
                local _, newTakeName = reaper.GetSetMediaItemTakeInfo_String(allTakenames[row].tk, 'P_NAME', returnTake, true)
            end
        end
    ImGui.EndTable(ctx)

    reaper.ImGui_EndChild(ctx)

    reaper.ImGui_Separator(ctx)

    -- DrawWaveform(ctx, selectedItems, current_selected1, 50)

    reaper.ImGui_End(ctx)
    end

    if open then
        reaper.defer(main) -- loop again
    else
        -- reaper.ImGui_DestroyContext(ctx)
    end
end

reaper.defer(main)

