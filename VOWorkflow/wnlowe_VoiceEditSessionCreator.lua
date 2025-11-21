-- @description Universal Import Script for VO Configuration
-- @author William N. Lowe
-- @version 1.05
-- @metapackage
-- @provides
--   [main] .
--   data/*.{py}
-- @changelog
--   # Repairing Python Support file
--   # Updating default window width
--   # 


local VSDEBUG
local s, r = pcall(function()
        VSDEBUG = dofile("C:\\Users\\ccuts\\.vscode\\extensions\\antoinebalaine.reascript-docs-0.1.15\\debugger\\LoadDebug.lua")
    end)


local USEROSWIN = reaper.GetOS():match("Win")
local SLASH = USEROSWIN and "\\" or "/"
local SCRIPT_PATH = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
SCRIPT_PATH = SCRIPT_PATH:gsub(SLASH, "/")
local SCRIPT_NAME = ({reaper.get_action_context()})[2]:match("([^/\\_]+)%.lua$")
local libPath = SCRIPT_PATH .. "../lib/"

package.path = package.path .. ";" .. libPath .. "?.lua"

local PYTHON_HELPER = SCRIPT_PATH .. SLASH .. "data" .. SLASH .. "ExcelToLua.py"

package.path = package.path .. ";" .. reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local imgui = require 'imgui' '0.10'

local CTX
local FLT_MIN, FLT_MAX = imgui.NumericLimits_Float()
local DBL_MIN, DBL_MAX = imgui.NumericLimits_Double()
local IMGUI_VERSION, IMGUI_VERSION_NUM, REAIMGUI_VERSION = imgui.GetVersion()



local WINDOW_SIZE = { width = 1200, height = 600 }
-- local WINDOW_FLAGS = imgui.WindowFlags_NoCollapse(1)

function Msg(msg)
    debug = true
    if debug then reaper.ShowConsoleMsg(tostring(msg))end
end

--------------------------------------------------------------------------------
-- FileLoader Class
--------------------------------------------------------------------------------
FileLoader = {}
FileLoader.__index = FileLoader
function FileLoader:new()
    local instance = setmetatable({}, FileLoader)
    return instance
end

-- function FileLoader:DoesFileExist(path)
--     local f = io.open(path, "r")
--     if f then f:close() end
--     return f ~= nil
-- end

function FileLoader:ConvertExcelToLua(excelPath) --Ouputs Path to Lua file
    local outputPath = excelPath:gsub("%.xlsx?$", ".lua")

    if reaper.file_exists(outputPath) then return outputPath end

    local command = string.format('python3 "%s" "%s" "%s"', PYTHON_HELPER, excelPath, outputPath)
    local result = os.execute(command)

    if result == 0 or result == true then
        return outputPath
    end
end

function FileLoader:LoadExcelFile(filePath) -- Returns Workbook
    local luaPath, err = self:ConvertExcelToLua(filePath)
    if err then
        return nil,nil, err
    end

    local workbook, metadata = dofile(luaPath)

    if not metadata then
        metadata = { ColumnFilter = {} }
    end

    return workbook, metadata
end

function FileLoader:GetSheetNames(data)
    local sheets = {}
    for s, _ in pairs(data) do
        table.insert(sheets, s)
    end

    return sheets
end

function FileLoader:GetDownloadsFolder()
    local downloadsPath
    if USEROSWIN then
        downloadsPath = os.getenv("USERPROFILE") .. "\\Downloads\\"
    else
        downloadsPath = os.getenv("HOME") .. "/Downloads/"
    end
    return downloadsPath
end

ScriptState = {}
ScriptState.__index = ScriptState

function ScriptState:new()
    local instance = setmetatable({}, ScriptState)
    instance.ctx = imgui.CreateContext("Excel Session Creator v2")
    instance.Open = true

    instance.ExcelPath = ''
    instance.FullData = nil

    instance.SheetNames = {}
    instance.CurrentSheetIdx = 0
    instance.CurrentSheetData = nil

    instance.RowIntentifyType = 0

    instance.ColumnHeaderRow = 1
    instance.ColumnFilter = {}

    instance.IndexColumnIdx = nil
    instance.IndexColumnHasLetter = false
    instance.NamesColumnIdx = nil

    instance.IdxOffset = nil
    instance.bShiftPreview = false

    instance.ImportFiles = false
    -- instance.ImportAlts = false

    instance.FindAndReplace = false
    instance.NumFindAndReplace = 1
    instance.Find = {}
    instance.Replace = {}

    instance.SelectMarker = false
    instance.SelectMarkerColumn = nil

    instance.LineText = true
    instance.LineTextIdx = nil

    instance.CharacterColumn = false
    instance.CharacterColumnIdx = nil
    instance.UpdateCharacterList = false
    instance.CharacterList = {}
    instance.SelectedCharacter = nil

    instance.StatusMessage = 'Load an Excel file to begin'
    instance.StatusColor = 0xFFFFFFFF

    instance.Loader = FileLoader:new()

    instance.RenamedCount = 0
    instance.bRename = false

    return instance
end

function ScriptState:SetStatus(message, color)
    self.StatusMessage = message
    self.StatusColor = color
end

function ScriptState:SetError(message)
    self:SetStatus(message, 0xFF0000FF)
end

function ScriptState:SetSuccess(message)
   self:SetStatus(message, 0xFF00FF00)
end

function ScriptState:SetWarning(message)
    self:SetStatus(message, 0xFFFF00FF)
end

function ScriptState:LoadFile(filePath)
    local data, metadata = self.Loader:LoadExcelFile(filePath)

    self.FullData = data
    self.ExcelPath = filePath
    self.SheetNames = self.Loader:GetSheetNames(data)

    if #self.SheetNames == 0 then
        self:SetError("No sheets found in file")
        return false
    end

    -- Restore all metadata fields
    if metadata then
        self.ColumnFilter = metadata.ColumnFilter or {}
        self.IndexColumnIdx = metadata.IndexColumnIdx
        self.IndexColumnHasLetter = metadata.IndexColumnHasLetter
        self.NamesColumnIdx = metadata.NamesColumnIdx
        self.ColumnHeaderRow = metadata.ColumnHeaderRow or 1
        self.IdxOffset = metadata.IdxOffset
        self.ImportFiles = metadata.ImportFiles or false
        self.CurrentSheetIdx = metadata.Sheet or 0
        self.SelectMarker = metadata.ShowMarker or false
        self.LineText = metadata.LineText or true
        self.LineTextIdx = metadata.LineColumnIdx
        self.FindAndReplace = metadata.FnR or false
        self.Find = metadata.Find or {}
        self.Replace = metadata.Replace or {}
    end

    self:LoadSheet(0)

    local filename = filePath:match("^.+/(.+)$") or filePath:match("^.+\\(.+)$") or filePath
    self:SetSuccess(string.format("Loaded: %s (%d sheets)", filename, #self.SheetNames))

    return true
end

function ScriptState:LoadSheet(sheetIdx)
    if not self.FullData or not self.SheetNames or sheetIdx >= #self.SheetNames then
        return false
    end

    local sheetName = self.SheetNames[sheetIdx + 1]
    self.CurrentSheetData = self.FullData[sheetName]

    self.CurrentSheetIdx = sheetIdx

    if not self.CurrentSheetData or #self.CurrentSheetData == 0 then
        self:SetWarning("Sheet is empty")
        return false
    end

    self:SetSuccess(string.format("Loaded sheet: %s (%d rows)", sheetName, #self.CurrentSheetData))
    return true
end

function ScriptState:SerializeMetadata()
    -- Build metadata table with all fields you want to save
    local metadata = {
        ColumnFilter = self.ColumnFilter,
        Sheet = self.CurrentSheetIdx,--
        IndexColumnIdx = self.IndexColumnIdx,
        IndexColumnHasLetter = self.IndexColumnHasLetter,
        ShowMarker = self.SelectMarker,--
        NamesColumnIdx = self.NamesColumnIdx,
        LineText = self.LineText,--
        LineColumnIdx = self.LineTextIdx,--
        ColumnHeaderRow = self.ColumnHeaderRow,
        IdxOffset = self.IdxOffset,
        ImportFiles = self.ImportFiles,
        FnR = self.FindAndReplace,--
        Find = self.Find,--
        Replace = self.Replace--
    }
    
    return metadata
end

function ScriptState:SerializeTable(tbl, indent)
    indent = indent or 0
    local spaces = string.rep("    ", indent)
    local lines = {}
    
    table.insert(lines, "{")

    for key, value in pairs(tbl) do
        local key_str = type(key) == "number" and string.format("[%d]", key) or key
        local value_str

        if type(value) == "table" then
            value_str = self:SerializeTable(value, indent + 1)
        elseif type(value) == "boolean" then
            value_str = value and "true" or "false"
        elseif type(value) == "number" then
            value_str = tostring(value)
        elseif type(value) == "string" then
            value_str = string.format('"%s"', value)
        elseif value == nil then
            value_str = "nil"
        else
            value_str = "nil"  -- Fallback for unsupported types
        end
        
        table.insert(lines, string.format("%s    %s = %s,", spaces, key_str, value_str))
    end
    
    table.insert(lines, spaces .. "}")
    
    return table.concat(lines, "\n")
end

function ScriptState:SaveMetadata()
    if not self.ExcelPath or self.ExcelPath == '' then
        return false
    end

    local luaPath = self.ExcelPath:gsub("%.xlsx?$", ".lua")

    if not reaper.file_exists(luaPath) then
        return false
    end

    -- Read the entire file
    local file = io.open(luaPath, "r")
    if not file then
        return false
    end
    local content = file:read("*all")
    file:close()

    -- Remove any existing metadata section
    local metadata_marker = "-- METADATA_START"
    local marker_pos = content:find(metadata_marker, 1, true)
    if marker_pos then
        content = content:sub(1, marker_pos - 1)
    end

    -- Get metadata and serialize it
    local metadata = self:SerializeMetadata()
    local metadata_str = self:SerializeTable(metadata)

    -- Build the metadata section
    local metadata_section = string.format(
        "\n-- METADATA_START\n-- This section stores UI state and preferences\nlocal metadata = %s\n\nreturn workbook, metadata",
        metadata_str
    )

    -- Write everything back
    file = io.open(luaPath, "w")
    if not file then
        return false
    end

    file:write(content)
    file:write(metadata_section)
    file:close()

    return true
end

function ScriptState:RenameItems()
    self.RenamedCount = 0
    self.bRename = true
end

function ScriptState:Destroy()
    self.ctx = nil
end



--------------------------------------------------------------------------------
-- GUI Class
--------------------------------------------------------------------------------

GUI = {}
GUI.__index = GUI

function GUI:new(state)
    CTX = state.ctx
    local instance = setmetatable({}, GUI)
    instance.state = state
    instance.ColumnWindow = false
    return instance
end

function GUI:BrowseForFile()
    self.state:SetWarning("Loading File...")
    local ret, filePath = reaper.GetUserFileNameForRead(self.state.Loader:GetDownloadsFolder(), "Select Excel File", ".xlsx; .xls")
    if ret then
        self.state:LoadFile(filePath)
    else
        self.state:SetError("No File Selected")
    end
end

function GUI:DrawFileSection()
    local state = self.state

    imgui.Text(state.ctx, "Excel File:")
    imgui.SameLine(state.ctx)

    if state.ExcelPath ~= "" then
        local filename = state.ExcelPath:match("^.+/(.+)$") or state.ExcelPath:match("^.+\\(.+)$") or state.ExcelPath
        imgui.TextColored(state.ctx, 0xFF00FFFF, filename)
    else
        imgui.TextColored(state.ctx, 0xFF808080, "No file loaded")
    end

    if imgui.Button(state.ctx, "Browse for Excel File") then
        self:BrowseForFile()
    end

    imgui.Separator(state.ctx)
end

function GUI:DrawSheetSelector()
    local state = self.state

    if not state.SheetNames or #state.SheetNames == 0 then
        return
    end

    imgui.Text(state.ctx, "Select Sheet:")

    local ComboStr = table.concat(state.SheetNames, "\0") .. "\0"
    local changed, NewIdx = imgui.Combo(state.ctx, "##SheetCombo", state.CurrentSheetIdx, ComboStr)

    if changed then
        state:LoadSheet(NewIdx)
    end

    imgui.Separator(state.ctx)
end

function GUI:DrawColumnFilterOpen()
    local state = self.state

    if not state.FullData then return end

    imgui.Indent(CTX, 25)
    imgui.PushStyleVar(CTX, imgui.StyleVar_ChildRounding, 10)
    imgui.PushStyleColor(CTX, imgui.Col_ChildBg, 0x3A1545FF)

    if imgui.BeginChild(CTX, "ColumnSettings", 775, 100) then
        imgui.Dummy(CTX, 10, 10)
        imgui.Indent(CTX, 20)
        if imgui.Button(state.ctx, "Filter Columns") then
            self.ColumnWindow = true
        end
        
        imgui.SameLine(state.ctx)
        imgui.Text(state.ctx, "Row Identify Type:")
        
        imgui.SameLine(state.ctx)
        imgui.SetNextItemWidth(CTX, 130)
        local comboTable = {"Column with select", "ID column", "Row Index"}
        local comboStr = table.concat(comboTable, "\0") .. "\0"
        local c, v = imgui.Combo(CTX, "##RowCombo", state.RowIntentifyType, comboStr)
        if c then state.RowIntentifyType = v end

        if v ~= 2 then
            imgui.SameLine(CTX)
            imgui.Text(CTX, "Select/ID Column")

            imgui.SameLine(CTX)
            imgui.SetNextItemWidth(state.ctx, 100)
            local changed, newValue = imgui.InputInt(state.ctx, "##IdxColumn", state.IndexColumnIdx)
            if changed and newValue >= 0 then
                state.IndexColumnIdx = newValue
                state.SelectMarkerColumn = state.IndexColumnIdx
            end

            imgui.SameLine(state.ctx)
            imgui.Text(CTX, "Has Letters?")
            imgui.SameLine(CTX)

            local c, bNewValue = imgui.Checkbox(state.ctx, "##bIdxLetters", state.IndexColumnHasLetter)
            if c then
                state.IndexColumnHasLetter = bNewValue
            end

            imgui.SameLine(CTX)
            imgui.Text(CTX, "Show Marker?")
            imgui.SameLine(CTX)
            local c, v = imgui.Checkbox(CTX, "##ShowMarker", state.SelectMarker)
            if c then 
                state.SelectMarker = v 
                state.SelectMarkerColumn = state.IndexColumnIdx 
            end


        else
            imgui.SameLine(CTX)
            imgui.Text(CTX, "Show Select Marker?")
            imgui.SameLine(CTX)
            local c, v = imgui.Checkbox(CTX, "##ShowMarker", state.SelectMarker)
            if c then 
                state.SelectMarker = v
                state.SelectMarkerColumn = state.IndexColumnIdx 
            end
            if v == true then
                imgui.SameLine(CTX)
                imgui.Text(CTX, "Select Column")
                imgui.SameLine(CTX)
                imgui.SetNextItemWidth(state.ctx, 100)
                local changed, newValue = imgui.InputInt(state.ctx, "##IdxColumn", state.IndexColumnIdx)
                if changed and newValue >= 0 then
                    state.IndexColumnIdx = newValue
                    state.SelectMarkerColumn = state.IndexColumnIdx
                end
            end
        end
        
        imgui.Indent(CTX, 75)

        imgui.Text(state.ctx, "Filename Column:")
        imgui.SameLine(state.ctx)

        imgui.SetNextItemWidth(state.ctx, 100)
        local changed, newValue = imgui.InputInt(state.ctx, "##FNames", state.NamesColumnIdx)
        if changed and newValue >= 0 then
            state.NamesColumnIdx = newValue
        end
        imgui.SameLine(CTX)
        imgui.Text(CTX,"Embed Line Text?")
        imgui.SameLine(CTX)
        local c, v = imgui.Checkbox(CTX, "##LineText", state.LineText)
        if c then state.LineText = v end

        if state.LineText then
            imgui.SameLine(CTX)
            imgui.Text(CTX, "Line Text Column:")
            imgui.SameLine(CTX)
            imgui.SetNextItemWidth(CTX, 100)
            local c, v = imgui.InputInt(CTX, "##LineTextIdx", state.LineTextIdx)
            if c and v > 0 then state.LineTextIdx = v end
        end

        imgui.Text(CTX, "Character Filter?")
        imgui.SameLine(CTX)
        c,v = imgui.Checkbox(CTX, "##CharFilCB", state.CharacterColumn)
        if c then state.CharacterColumn = v end
        if state.CharacterColumn then
            imgui.SameLine(CTX)
            imgui.Text(CTX, "Character Name Col:")
            imgui.SameLine(CTX)
            imgui.SetNextItemWidth(CTX, 100)
            local c, v = imgui.InputInt(CTX, "##CharColumn", state.CharacterColumnIdx)
            if c and v > 0 then
                state.CharacterColumnIdx = v
                state.UpdateCharacterList = true
            end
            --Find all names in the character column
            if state.CharacterList then
                imgui.SameLine(CTX)
                imgui.Text(CTX, "Select Character:")
                imgui.SameLine(CTX)
                imgui.SetNextItemWidth(CTX, 100)
                local comboStr = table.concat(state.CharacterList, "\0") .. "\0"
                local c, v = imgui.Combo(CTX, "##CharCombo", state.SelectedCharacter, comboStr)
                if c then state.SelectedCharacter = v end
            end

        end
        --Add Line Text column
        imgui.Unindent(CTX, 75)

        imgui.Unindent(CTX, 20)
        imgui.EndChild(CTX)
    end
    imgui.PopStyleColor(CTX)
    imgui.PopStyleVar(CTX)
    imgui.Unindent(CTX, 25)


    

    
    

end

function GUI:DrawColumnFilterWindow()
    local state = self.state

    if not self.ColumnWindow then return end

    -- Calculate approximate width needed for all checkboxes
    local headerRow = state.CurrentSheetData[state.ColumnHeaderRow]
    -- local contentWidth = 0
    -- if headerRow and type(headerRow) == "table" then
    --     -- Estimate ~100 pixels per checkbox (adjust as needed)
    --     contentWidth = #headerRow * 300
    -- end

    -- -- Set content size BEFORE Begin()
    -- imgui.SetNextWindowContentSize(state.ctx, contentWidth, 0)
    imgui.SetNextWindowSize(state.ctx, 400, 300, imgui.Cond_FirstUseEver)
    
    local visible, open = imgui.Begin(state.ctx, 'Column Filtering', true, 2048)

    if visible then
        if headerRow and type(headerRow) == "table" then
            for i = 1, #headerRow do
                if state.ColumnFilter[i] == nil then state.ColumnFilter[i] = true end

                local txt = tostring(headerRow[i])
                local label = txt .. "##col" .. i

                local changed, newValue = imgui.Checkbox(state.ctx, label, state.ColumnFilter[i])
                if changed then
                    state.ColumnFilter[i] = newValue
                end
                if i < #headerRow then imgui.SameLine(state.ctx) end
            end
        end
    end
    
    imgui.End(state.ctx)

    if not open then
        self.ColumnWindow = false
        state:SaveMetadata()
    end
end

function GUI:DrawHeaderRowSelector()
    local state = self.state

    if not state.FullData then return end

    imgui.Text(state.ctx, "Header Row:")
    imgui.SameLine(state.ctx)

    imgui.SetNextItemWidth(state.ctx, 300)
    local changed, NewValue = imgui.InputInt(state.ctx, "##HeaderRow", state.ColumnHeaderRow)

    if changed and NewValue >=0 then
        state.ColumnHeaderRow = NewValue
        state:LoadSheet(state.CurrentSheetIdx)
    end

    imgui.SameLine(state.ctx)
    imgui.TextDisabled(state.ctx, "(1 = first row)")

    imgui.Separator(state.ctx)
end

function GUI:DrawCurrentSheetDataPreview()
    local state = self.state
    if not state.CurrentSheetData or #state.CurrentSheetData == 0 then
        return
    end

    imgui.Text(state.ctx, string.format("Data Preview (%d rows):", #state.CurrentSheetData))

    

    -- Try the older BeginChild syntax without ChildFlags_Border
    -- local childFlags = imgui.WindowFlags_HorizontalScrollbar
    if imgui.BeginChild(state.ctx, "Data Preview", 0, 200, 0) then
        local previewRows = math.min(10, #state.CurrentSheetData)
        if previewRows == 10 then previewRows = previewRows + state.ColumnHeaderRow end

        local totalCols = 0
        if state.CurrentSheetData[1] and type(state.CurrentSheetData[1]) == "table" then 
            totalCols = #state.CurrentSheetData[1]
        end

        local visibleCols = {}
        for j = 1, totalCols do
            if state.ColumnFilter[j] == nil or state.ColumnFilter[j] == true then
                table.insert(visibleCols, j)
            end
        end

        imgui.PushStyleColor(CTX, imgui.Col_TableBorderStrong, 0x808080FF)  -- Outer borders
        imgui.PushStyleColor(CTX, imgui.Col_TableBorderLight, 0x606060FF)

        local flags = imgui.TableFlags_Borders |
        imgui.TableFlags_RowBg |
        imgui.TableFlags_SizingFixedFit |
        imgui.TableFlags_ScrollX

        if imgui.BeginTable(CTX, "PreviewTable", #visibleCols, flags) then
            imgui.TableNextRow(CTX)
            for _, j in ipairs(visibleCols) do
                imgui.TableNextColumn(CTX)
                imgui.TableSetBgColor(CTX, imgui.TableBgTarget_CellBg, 0x404040FF)  -- Dark gray background
                imgui.TextColored(CTX, 0xFFFFFFFF, "Col " .. j)
            end

            for i = state.ColumnHeaderRow, previewRows do

                if state.CurrentSheetData[i] and type(state.CurrentSheetData[i]) == "table" then
                    imgui.TableNextRow(CTX)
                    for _, j in ipairs(visibleCols) do
                        imgui.TableNextColumn(CTX)
                        local cellValue = state.CurrentSheetData[i][j]
                        
                        if cellValue == nil then cellValue = "" end
                        if i == state.ColumnHeaderRow then imgui.TableSetBgColor(CTX, imgui.TableBgTarget_CellBg, 0x266618FF)
                        elseif state.IndexColumnIdx and j == state.IndexColumnIdx then imgui.TableSetBgColor(CTX, imgui.TableBgTarget_CellBg, 0x826A10FF)
                        elseif state.NamesColumnIdx and j == state.NamesColumnIdx then imgui.TableSetBgColor(CTX, imgui.TableBgTarget_CellBg, 0x229C91FF)
                        elseif state.LineTextIdx and j == state.LineTextIdx then imgui.TableSetBgColor(CTX, imgui.TableBgTarget_CellBg, 0x681273FF)
                        elseif state.CharacterColumnIdx and state.CharacterColumn and j == state.CharacterColumnIdx then 
                            imgui.TableSetBgColor(CTX, imgui.TableBgTarget_CellBg, 0x8A2727FF)
                        end

                        
                        imgui.Text(CTX, tostring(cellValue))
                    end
                    
                end
            end
            imgui.EndTable(CTX)
        end

        imgui.PopStyleColor(CTX, 2)

        if #state.CurrentSheetData > 10 then
            imgui.Text(state.ctx, string.format("... and %d more rows", #state.CurrentSheetData - 10))
        end
        
        imgui.EndChild(state.ctx)
    end
    

    imgui.Separator(state.ctx)
end

function GUI:DrawIndexOffsetSection()
    local state = self.state

    if not state.FullData or state.IndexColumnHasLetter then return end

    imgui.Text(CTX, "Index Offset:")
    imgui.SameLine(CTX)
    imgui.SetNextItemWidth(CTX, 300)
    local c, newV = imgui.InputInt(CTX, "##OFFSET", state.IdxOffset)

    if c then
        state.IdxOffset = newV
    end

    imgui.SameLine(CTX)
    imgui.Text(CTX, "Shift Preview?")
    imgui.SameLine(CTX)
    local c, b = imgui.Checkbox(CTX, "##bShift", state.bShiftPreview)

    if c then state.bShiftPreview = b end

    imgui.Separator(CTX)

end

function GUI:DrawActionButton()
    local state = self.state

    --AUDIO FILE IMPORT
    imgui.Text(CTX, "Importing Audio Files?")
    imgui.SameLine(CTX)
    local c, val = imgui.Checkbox(CTX, "##bImport", state.ImportFiles)

    if c then state.ImportFiles = val end

    -- if state.ImportFiles then
    --     imgui.SameLine(CTX)
    --     imgui.Text(CTX, "Import Alts?")
    --     imgui.SameLine(CTX)
    --     local c, v = imgui.Checkbox(CTX, "##bAlts", state.ImportAlts)
    --     if c then state.ImportAlts = v end
    -- end

    --FIND AND REPLACE
    imgui.Text(CTX, "Find and replace in filenaming?")
    imgui.SameLine(CTX)
    c, val = imgui.Checkbox(CTX, "##bFindAndReplace", state.FindAndReplace)

    if c then state.FindAndReplace = val end

    if state.FindAndReplace then
        imgui.SameLine(CTX)
        imgui.Text(CTX, "Num F & R:")
        imgui.SameLine(CTX)
        imgui.SetNextItemWidth(state.ctx, 100)
        local changed, newValue = imgui.InputInt(state.ctx, "##IdxFnR"..tostring(i), state.NumFindAndReplace)
        if changed and newValue > 0 then
            state.NumFindAndReplace = newValue
        end
        for i = 1, state.NumFindAndReplace do
            imgui.Text(CTX,"Find:")
            imgui.SameLine(CTX)
            imgui.SetNextItemWidth(CTX, 100)
            local c, t = imgui.InputText(CTX, "##Find", state.Find[i])
            if c and t ~= "" and t then
                state.Find = t
            elseif t == "" and c then

            end

            imgui.SameLine(CTX)
            imgui.Text(CTX,"Replace:")
            imgui.SameLine(CTX)
            imgui.SetNextItemWidth(CTX, 100)
            c, t = imgui.InputText(CTX, "##Replace", state.Replace[i])
            if c then state.Replace[i] = t end
        end
    end

    --EXECUTION BUTTON
    if imgui.Button(state.ctx, "Rename Selected Items", 200, 30) then
        state:RenameItems()
    end

    imgui.Separator(state.ctx)
    -- state:SaveMetadata()
end

function GUI:DrawStatusBar()
    local state = self.state
    imgui.TextColored(state.ctx, state.StatusColor, state.StatusMessage)
end

function GUI:Draw()
    local state = self.state

    imgui.SetNextWindowSize(state.ctx, WINDOW_SIZE.width, WINDOW_SIZE.height, imgui.Cond_FirstUseEver)
    local flags = 2048 | imgui.WindowFlags_NoCollapse
    local visible, open = imgui.Begin(state.ctx, 'Excel Item Renamer', true, flags)

    if visible then

        self:DrawFileSection()
        self:DrawSheetSelector()
        self:DrawHeaderRowSelector()
        self:DrawColumnFilterOpen()
        self:DrawColumnFilterWindow()
        self:DrawCurrentSheetDataPreview()
        if state.RowIntentifyType == 1 then
            self:DrawIndexOffsetSection()
        end
        self:DrawActionButton()
        self:DrawStatusBar()


    end
    imgui.End(state.ctx)

    state.open = open

    if not state.open then
        state:SaveMetadata()
        state:Destroy()
    end
end

--------------------------------------------------------------------------------
-- Application Class
--------------------------------------------------------------------------------
Application = {}
Application.__index = Application

function Application:new()
  local instance = setmetatable({}, Application)
  instance.state = ScriptState:new()
  instance.gui = GUI:new(instance.state)
  return instance
end

function Application:InsertAlt(mediaItem, endTime, track, str)
    local state = self.state
    local select = string.match(str, "(%d+)%s*$")
    if not select then return end
    select = tonumber(select)


end

function Application:Rename()
    local mediaItems = {}
    local state = self.state
    local renamed = 0
    local fileList = {}
    local numItems = 0

    state:SaveMetadata()

    if state.ImportFiles then
        local r, directory = reaper.JS_Dialog_BrowseForFolder("Select a Folder", state.Loader:GetDownloadsFolder())
        local idx = 0
        local slash = nil
        if USEROSWIN then slash = "\\" else slash = "/" end
        local file = reaper.EnumerateFiles(directory, idx)
        while file ~= nil do
            local f = directory .. slash .. file
            table.insert(fileList, f)
            reaper.InsertMedia(f, 0)
            reaper.MoveEditCursor(1, false)
            local item = reaper.GetMediaItem( 0, reaper.CountMediaItems(0) - 1 )
            reaper.SetMediaItemSelected(item , true )
            idx = idx + 1
            file = reaper.EnumerateFiles(directory, idx)
        end
    end
    numItems = reaper.CountSelectedMediaItems(0)
    if numItems < 1 then state:SetError("No Items Selected!") return end
    for i = 0, numItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        local r, sourceName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        sourceName = tostring(sourceName)
        local index = sourceName:match("_([^_]*)$")
        index = string.match(index, "^(%d+)")
        index = tonumber(index)
        if state.IdxOffset and tonumber(state.IdxOffset) ~= 0 and index then
            index = index + tonumber(state.IdxOffset)
        end
        if index then mediaItems[index] = item renamed = renamed + 1 end
    end

    if state.CurrentSheetData == nil then return end
    for i = state.ColumnHeaderRow + 1, #state.CurrentSheetData do
        if state.CharacterColumn then
            if state.CurrentSheetData[i][state.CharacterColumnIdx] ~= state.CharacterList[state.SelectedCharacter + 1] then goto continue end
        end
        local tableValue = nil
        if state.SelectMarker then
            tableValue = state.CurrentSheetData[i][state.SelectMarkerColumn]
            if tableValue then tableValue = string.match(tableValue, "^(%d+)") end
        else
            tableValue = state.CurrentSheetData[i][state.IndexColumnIdx]
        end

        if tableValue ~= nil and tonumber(tableValue) ~= nil then
            tableValue = tonumber(tableValue)
            --Table Value is the index number, if there is a corresponding value we continue. 
            if mediaItems[tableValue] ~= nil then
                local mi = mediaItems[tableValue]
                local startT, endT
                startT = reaper.GetMediaItemInfo_Value(mi, "D_POSITION")
                endT = startT + reaper.GetMediaItemInfo_Value(mi, "D_LENGTH")
                --Find and Replace
                local fileName = state.CurrentSheetData[i][state.NamesColumnIdx]
                if #state.Find > 0 and state.Find[1] ~= '' then
                    for a = 1, #state.Find do
                        fileName:gsub(state.Find[a], state.Replace[a])
                    end
                end
                --Add Region
                local region = reaper.AddProjectMarker(0, true, startT, endT, fileName, -1)
                --Add to Render Matrix
                local track = reaper.GetMediaItemInfo_Value(mi, "P_TRACK")
                reaper.SetRegionRenderMatrix( 0, region, track, 2 )
                --Add Select Marker
                if state.SelectMarker then
                    local markerName = state.CurrentSheetData[i][state.SelectMarkerColumn]
                    local marker = reaper.AddProjectMarker(0, false, startT, startT, markerName, -1)
                    local altFound = string.match(string.lower(markerName), "alt")
                    if altFound then
                        --self:InsertAlt(mi, endT, track, markerName) 
                    end
                end
                --Set Line Note
                if state.LineText then
                    local text = state.CurrentSheetData[i][state.LineTextIdx]
                    if text then
                        reaper.GetSetMediaItemInfo_String(mi, "P_NOTES", text, true)
                    end
                end

                state.RenamedCount = state.RenamedCount + 1
                if state.RenamedCount >= renamed then
                    --goto foundAll 
                    break
                end
            end
        end
        ::continue::
    end
    -- ::foundAll::
    state:SetSuccess(string.format("Renamed %d items", state.RenamedCount))
    state.bRename = false
end

function Application:Characters()
    local state = self.state
    local col = state.CharacterColumnIdx
    local characters = {}
    for i = state.ColumnHeaderRow + 1, #state.CurrentSheetData do
        local cell = state.CurrentSheetData[i][col]
        if #characters < 1 and cell then
            table.insert(characters, cell)
        else
            local found = false
            for j = 1, #characters do
                if cell == characters[j] then found = true break end
            end
            if not found then table.insert(characters, cell) end
        end
    end
    if characters then state.CharacterList = characters end
    state.UpdateCharacterList = false
end

function Application:Run()
    self.gui:Draw()

    if self.state.UpdateCharacterList then self:Characters() end
    if self.state.bRename then self:Rename() end

    if self.state.open then
        reaper.defer(function() self:Run() end)
    end
end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------
local app = Application:new()
app:Run()