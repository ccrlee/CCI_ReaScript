--[[ 
description: Custom GUI Bar for VO Configuration
author: William N. Lowe
version: 1.21.2
provides:
  wnlowe_lufsSet__shouted.lua
  wnlowe_lufsSet__spoken.lua
  wnlowe_lufsSet__whisper.lua
  wnlowe_lufsSet__yelled.lua
  wnlowe_playMatchFile_shouted.lua
  wnlowe_playMatchFile_spoken.lua
  wnlowe_playMatchFile_whispered.lua
  wnlowe_playMatchFile_yelled.lua
  wnlowe_resetMatchFolder.lua
changelog:
   1.21
   # Match File Character Specific Bug
   1.20.2
  # Adding VOFX Measure time from previous item
  # Adding GUI for new Feature
--]]

local DEBUG = true
local USEROSWIN = reaper.GetOS():match("Win")
local SCRIPT_PATH = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
SCRIPT_PATH = USEROSWIN and SCRIPT_PATH:gsub("\\", "/") or SCRIPT_PATH
local SLASH = USEROSWIN and "\\" or "/"
local libPath = SCRIPT_PATH .. "../lib/"
package.path = package.path .. ";" .. libPath .. "?.lua"
package.path = package.path .. ";" .. reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local imgui = require 'imgui' '0.10'
local CTX
local WINDOW_SIZE = { width = 400, height = 100 }
local combo_flags = { current_selected = 1 }

local VSDEBUG
local s, r = pcall(function()
        if DEBUG then
            VSDEBUG = dofile("C:\\Users\\ccuts\\.vscode\\extensions\\antoinebalaine.reascript-docs-0.1.15\\debugger\\LoadDebug.lua")
        end
    end)

function Msg(msg)
    if DEBUG then reaper.ShowConsoleMsg(tostring(msg) .. "\n")end
end

LUFSManager = {}
LUFSManager.__index = LUFSManager
function LUFSManager:new()
    local instance = setmetatable({}, LUFSManager)
    CTX = imgui.CreateContext("LUFS Manager")
    instance.open = true
    instance.unsavedSession = false

    instance.MetadataFilePath = nil

    instance.LoudnessCategories = {"Whispered", "Spoken", "Yelled"}
    instance.TargetsI = {-20, -18, -14}
    instance.TargetsM = {-16, -15, -11}
    instance.TargetOffsets = {0, 0, 0}
    instance.LUFSActions = {}
    instance.MatchActions = {}
    instance.TargetColors = {0x893CC3FF, 0xec008cFF, 0xd7e800FF}
    instance.CategoryColors = {{0x002C87FF, 0x0055FFFF}, {0x096E00FF, 0x0ED100FF}}

    instance.CutoffTime = 3

    instance.RefreshMatchAction = nil
    instance.StopMatchAction = nil

    instance.folders = {}
    instance.files = {}
    instance.referenceTrack = nil
    instance.characterTable = {[1] = "All"}
    instance.character = "All"
    instance.characterIdx = 0

    instance.VOFXAction = nil
    instance.VOFXSel = 0
    instance.VOFXModes = {"Letters", "Numbers", "Num_Char"}
    instance.VOFXTiming = 1
    instance.VOFXAddTime = true
    instance.VOFXFromStart = false

    instance.NumLoudnessCategories = 3
    return instance
end

function LUFSManager:EvaluateBoolMetadata(value)
    if value == nil then return nil end
    return value == "true" and true or false
end

function LUFSManager:LoadMetadata()
    local projectPath = reaper.GetProjectPath()
    local dir = nil
    if projectPath ~= "" and projectPath ~= "C:\\Users\\ccuts\\Documents\\REAPER Media" then
        dir = projectPath
    else
        self.unsavedSession = true
        self:FindActions()
        return false
    end

    local filePath = dir.. SLASH .. "LoudnessSettings.lua"
    local r = reaper.file_exists(filePath)
    if not self.MetadataFilePath then self.MetadataFilePath = filePath end
    if not r then
        self:FindActions()
        self:SaveMetadata()
        return
    end

    local metadata = nil
    local directories = nil
    local status, result = pcall(function()
        metadata, directories = dofile(filePath)
    end)
    if not status then self.unsavedSession = true Msg(result) end
    if metadata then
        local m = metadata
        self.TargetOffsets = m["Offsets"] or self.TargetOffsets
        self.CutoffTime = m["CutoffTime"] or self.CutoffTime
        self.TargetsI = m["TargetsI"] or self.TargetsI
        self.TargetsM = m["TargetsM"] or self.TargetsM
        self.VOFXModes = m["VOFXModes"] or self.VOFXModes
        self.VOFXSel = m['VOFXSel'] or self.VOFXSel
        self.LoudnessCategories = m["LoudnessCategories"] or self.LoudnessCategories
        self.TargetColors = m["TargetColors"] or self.TargetColors
        self.CategoryColors = m["CategoryColors"] or self.CategoryColors
        self.VOFXTiming = m["VOFXTiming"] or self.VOFXTiming
        self.VOFXAddTime = self:EvaluateBoolMetadata(m["VOFXAddTime"]) or self.VOFXAddTime
        self.VOFXFromStart = self:EvaluateBoolMetadata(m["VOFXFromStart"]) or self.VOFXFromStart
        -- self.WhisperedTargetI, self.SpokenTargetI, self.YelledTargetI = table.unpack(m["TargetsI"])
        -- self.WhisperedTargetM, self.SpokenTargetM, self.YelledTargetM = table.unpack(m["TargetsM"])
        -- self.WhisperedOffset = m["Offsets"][1]
        -- self.SpokenOffset = m["Offsets"][2]
        -- self.YelledOffset = m["Offsets"][3]
    end
    if directories then
        local d = directories
        self.folders = d["folders"]
        self.files = d["files"]
        self.referenceTrack = d["referenceTrack"]
        self.character = d["character"]
    end
    local counter = 2
    if self.folders["characters"] then
        for k, v in pairs(self.folders["characters"]) do
            table.insert(self.characterTable, counter, k)
            counter = counter + 1
        end
    end
    self:FindActions()
end

function LUFSManager:FindActions()
    local actionNames = {
        ["Script: wnlowe_lufsSet__shouted.lua"] = function(id) self.LUFSActions[4] = id end,
        ["Script: wnlowe_lufsSet__spoken.lua"] = function(id) self.LUFSActions[2] = id end,
        ["Script: wnlowe_lufsSet__whisper.lua"] = function(id) self.LUFSActions[1] = id end,
        ["Script: wnlowe_lufsSet__yelled.lua"] = function(id) self.LUFSActions[3] = id end,
        ["Script: wnlowe_playMatchFile_shouted.lua"] = function(id) self.MatchActions[4] = id end,
        ["Script: wnlowe_playMatchFile_spoken.lua"] = function(id) self.MatchActions[2] = id end,
        ["Script: wnlowe_playMatchFile_whispered.lua"] = function(id) self.MatchActions[1] = id end,
        ["Script: wnlowe_playMatchFile_yelled.lua"] = function(id) self.MatchActions[3] = id end,
        ["Script: wnlowe_resetMatchFolder.lua"] = function(id) self.RefreshMatchAction = id end,
        ["Script: wnlowe_stopAllPreviews.lua"] = function(id) self.StopMatchAction = id end,
        ["Script: wnlowe_VOFXRegions_Illusion.lua"] = function(id) self.VOFXAction = id end,
    }
    local section = 0
    local i = 0
    repeat
        local r, name = reaper.kbd_enumerateActions(section, i)
        if r and r ~= 0 and actionNames[name] then actionNames[name](r) end
        i = i + 1
    until not r or r == 0 or (self.ShoutedLUFSAction and self.SpokenLUFSAction and self.WhisperedLUFSAction and self.YelledLUFSAction and self.VOFXAction)
end

function LUFSManager:SerializeMetadata()
    local metadata = {
        TargetsI = self.TargetsI,
        TargetsM = self.TargetsM,
        Offsets = self.TargetOffsets,
        CutoffTime = self.CutoffTime,
        VOFXSel = self.VOFXSel,
        VOFXModes = self.VOFXModes,
        LoudnessCategories = self.LoudnessCategories,
        TargetColors = self.TargetColors,
        CategoryColors = self.CategoryColors,
        VOFXTiming = self.VOFXTiming,
        VOFXAddTime = self.VOFXAddTime,
        VOFXFromStart = self.VOFXFromStart
    }
    return metadata
end

function LUFSManager:SerializeDirectories()
    local directories = {
        folders = self.folders,
        files = self.files,
        referenceTrack = self.referenceTrack,
        character = self.character
    }
    return directories
end

function LUFSManager:SerializeTable(tbl, indent)
    indent = indent or 0
    local spaces = string.rep("     ", indent)
    local lines = {}
    table.insert(lines, "{")

    for key,value in pairs(tbl) do
        local keyStr = type(key) == "number" and string.format("[%d]", key) or key
        local valStr
        if type(value) == "table" then
            valStr = self:SerializeTable(value, indent + 1)
        elseif type(value) == "number" then
            valStr = tostring(value)
        elseif type(value) == "string" then
            local escaped = value:gsub("\\", "\\\\")
            valStr = string.format('"%s"', escaped)
        elseif type(value) == "boolean" then
            valStr = tostring(value)
        elseif value == nil then
            valStr = "nil"
        else
            valStr = "nil"
        end

        table.insert(lines, string.format("%s   %s = %s,", spaces, keyStr, valStr))
    end
    table.insert(lines, spaces .. "}")
    return table.concat(lines, "\n")
end

function LUFSManager:SaveMetadata()
    if self.unsavedSession then return end
    if not self.MetadataFilePath then
        local projectPath = reaper.GetProjectPath()
        local dir = nil
        if projectPath ~= "" then dir = projectPath
        else reaper.ShowMessageBox("Project is not saved!", "Script Error", 0) return false end

        self.MetadataFilePath = dir.."/LoudnessSettings.lua"
        self:SaveMetadata()
    end
    local metadata = self:SerializeMetadata()
    local directories = self:SerializeDirectories() --
    local metadataStr = self:SerializeTable(metadata)
    local directoriesStr = self:SerializeTable(directories)
    local outputStr = string.format("local metadata = %s local directories = %s return metadata, directories", metadataStr, directoriesStr)
    local file = io.open(self.MetadataFilePath, "w")
    if not file then return false end
    file:write(outputStr)
    file:close()
end

Gui = {}
Gui.__index = Gui
function Gui:new(manager)
    local instance = setmetatable({}, Gui)

    instance.manager = manager

    instance.firstRun = true
    instance.includeScreamed = false

    instance.showSettings = false
    instance.refreshMatch = false
    instance.stopMatch = false
    instance.maintainFocus = true

    instance.vofxSettings = nil

    return instance
end

function Gui:SavedSession()
    local manager = self.manager
    manager.unsavedSession = false
    manager:SaveMetadata()
end

function Gui:DrawMainSection()
    local manager = self.manager
    local inputSize = ((560 / 3) + 5) * (manager.NumLoudnessCategories)
    local fullSize = imgui.GetContentRegionAvail(CTX)
    local center = fullSize / 2
    local buttonHeight = 27

    imgui.PushStyleVar(CTX, imgui.StyleVar_FrameRounding, 8)
    imgui.PushStyleVar(CTX, imgui.StyleVar_FrameBorderSize, 2.0)
    
    imgui.PushStyleColor(CTX, imgui.Col_Border, 0xC8C7CBFF)
    imgui.PushStyleColor(CTX, imgui.Col_Button, 0x4E4E56FF)
    imgui.PushStyleColor(CTX, imgui.Col_ButtonHovered, 0x7C7C83FF)

    -------------- SETTINGS BUTTONS
    if imgui.Button(CTX, "Target Settings", 85, buttonHeight) then
        self.showSettings = true
    end

    imgui.SameLine(CTX)
    if imgui.Button(CTX, "Refresh Match", 85, buttonHeight) then
        self.refreshMatch = true
    end

    imgui.SameLine(CTX)
    if imgui.Button(CTX, "Stop Match", 70, buttonHeight) then
        reaper.Main_OnCommand(manager.StopMatchAction, 0)
    end

    imgui.PopStyleColor(CTX, 2)
    imgui.PushStyleColor(CTX, imgui.Col_Button, 0x780000FF)
    imgui.PushStyleColor(CTX, imgui.Col_ButtonHovered, 0xFF8A8AFF)
    if manager.unsavedSession then
        imgui.SameLine(CTX)
        if imgui.Button(CTX, "Saved Session", 85, buttonHeight) then
            self:SavedSession()
        end
    end
    imgui.PopStyleColor(CTX, 2)

    ------------- LUFS BUTTONS
    local numButtons = manager.NumLoudnessCategories + 1
    imgui.SameLine(CTX)
    local remainingSpace = imgui.GetContentRegionAvail(CTX)
    remainingSpace = remainingSpace - center
    local buttonWidth = 85 + 20
    local buttonSpace = manager.NumLoudnessCategories < 5 and buttonWidth * (numButtons) or buttonWidth * (numButtons + 2) 
    -- Msg(remainingSpace - buttonSpace)
    imgui.Dummy(CTX, remainingSpace - buttonSpace, 25)

    --LUFS Buttons
    local lufsMainColor = (manager.CategoryColors and manager.CategoryColors[1] and manager.CategoryColors[1][1]) or 0x002C87FF
    local lufsHoverColor = (manager.CategoryColors and manager.CategoryColors[1] and manager.CategoryColors[1][2]) or 0x0055FFFF
    imgui.PushStyleColor(CTX, imgui.Col_Button, lufsMainColor)
    imgui.PushStyleColor(CTX, imgui.Col_ButtonHovered, lufsHoverColor)
    for i = 1, manager.NumLoudnessCategories do
        imgui.SameLine(CTX)
        local text = string.format("LUFS %s", manager.LoudnessCategories[i] or ("Level " .. i))
        local textW, textH = imgui.CalcTextSize(CTX, text)
        imgui.PushStyleColor(CTX, imgui.Col_Border, manager.TargetColors[i] or 0x000000FF)
        if imgui.Button(CTX, text, textW + 15, buttonHeight) then
            if manager.LUFSAction[i] then 
                reaper.Main_OnCommand(manager.LUFSActions[i], 0)
                self.maintainFocus = false
            else reaper.ShowMessageBox(string.format("Action Not Found for %s!", manager.LoudnessCategories[i] or ("Level " .. i)), "Script Error", 0) end
        end
        imgui.PopStyleColor(CTX, 1)
    end
    imgui.PopStyleColor(CTX, 2)

    -- MATCH BUTTONS
    local matchMainColor = (manager.CategoryColors and manager.CategoryColors[2] and manager.CategoryColors[2][1]) or 0x096E00FF
    local matchHoverColor = (manager.CategoryColors and manager.CategoryColors[2] and manager.CategoryColors[2][2]) or 0x0ED100FF
    imgui.PushStyleColor(CTX, imgui.Col_Button, matchMainColor)
    imgui.PushStyleColor(CTX, imgui.Col_ButtonHovered, matchHoverColor)
    for i = 1, manager.NumLoudnessCategories do
        imgui.SameLine(CTX)
        local text = string.format("Match %s", manager.LoudnessCategories[i] or ("Level " .. i))
        local textW, textH = imgui.CalcTextSize(CTX, text)
        imgui.PushStyleColor(CTX, imgui.Col_Border, manager.TargetColors[i] or 0x000000FF)
        if imgui.Button(CTX, text, textW + 15, buttonHeight) then
            if manager.MatchActions[i] then 
                reaper.Main_OnCommand(manager.MatchActions[i], 0)
                self.maintainFocus = false
            else reaper.ShowMessageBox(string.format("Action Not Found for %s!", manager.LoudnessCategories[i] or ("Level " .. i)), "Script Error", 0) end
        end
        imgui.PopStyleColor(CTX, 1)
    end
    imgui.PopStyleColor(CTX, 2)

    imgui.SameLine(CTX)
    if imgui.Button(CTX, "VOFX", 75, buttonHeight) then
        reaper.Main_OnCommand(manager.VOFXAction, 0)
        -- Msg(items[combo_flags.current_selected]['func']('test', 1))
        self.maintainFocus = false
    end

    imgui.PopStyleVar(CTX, 2)
    imgui.PopStyleColor(CTX, 1)

    ------------ Settings Boxes
    imgui.SameLine(CTX)
    remainingSpace = imgui.GetContentRegionAvail(CTX)
    -- Msg(remainingSpace - inputSize)
    imgui.Dummy(CTX, remainingSpace - inputSize, 25)

    for i = 1, manager.NumLoudnessCategories do
        imgui.SameLine(CTX)
        imgui.SetNextItemWidth(CTX, 100)
        local c, newV = imgui.InputDouble(CTX, string.format("%s Offset ##%sO", manager.LoudnessCategories[i] or ("Level " .. i), i), manager.TargetOffsets[i], 0.5, 1.0, "%.2f")
        if c then
            manager.TargetOffsets[i] = newV
            manager:SaveMetadata()
        end
    end
end


function Gui:DrawSettingsWindow()
    local manager = self.manager
    local breakSize = 10

    imgui.SetNextWindowSize(CTX, 400, 600, imgui.Cond_FirstUseEver)
    local visible, open = imgui.Begin(CTX, "Settings", true, 2048)

    if visible then
        imgui.Text(CTX, "Common Settings")
        imgui.SetNextItemWidth(CTX, 100)
        local c, newV = imgui.InputDouble(CTX, "Cutoff Time between LUFS-M and LUFS-I ##CT", manager.CutoffTime, 0.5, 1.0, "%.2f")
        if c then manager.CutoffTime = newV manager:SaveMetadata() end

        local count = 0
        local dropdown = false
        for _ in pairs(manager.folders) do
            count = count + 1
            if count > 3 then
                dropdown = true
                break
            end
        end
        if dropdown then
            local c, v = imgui.Combo(CTX, "Character Match Selection ##CMS", manager.characterIdx, table.concat(manager.characterTable, "\0") .. "\0")
            if c then
                manager.characterIdx = v
                manager.character = manager.characterTable[v + 1]
            end
        end

        if not self.vofxSettings then self.vofxSettings = table.concat(manager.VOFXModes, "\0") .. "\0" end
        local c, v = imgui.Combo(CTX, "VOFX Mode ##CVOFX", manager.VOFXSel, self.vofxSettings)
        if c then manager.VOFXSel = v end

        imgui.Dummy(CTX, 25, breakSize * 2)
        imgui.Text(CTX, "General Preferences")

        imgui.SetNextItemWidth(CTX, 100)
        local c, v = imgui.SliderInt(CTX, "Number of Loudness Categories ##SNC", manager.NumLoudnessCategories, 3, 5)
        if c then manager.NumLoudnessCategories = v end

        imgui.SetNextItemWidth(CTX, 100)
        local c, v = imgui.InputDouble(CTX, "Spacing Between VOFX ##VOT", manager.VOFXTiming, 0.1, 0.25, "%.2f")
        if c then manager.VOFXTiming = v end

        local c, v = imgui.Checkbox(CTX, "Insert Time for VOFX Spacing ##VOS", manager.VOFXAddTime)
        if c then manager.VOFXAddTime = v end

        local c, v = imgui.Checkbox(CTX, "Measure time from start of previous item ##VOP", manager.VOFXFromStart)
        if c then manager.VOFXFromStart = v end

        imgui.TextDisabled(CTX, "Category Names")

        for i = 1, manager.NumLoudnessCategories do
            local c, v = imgui.InputText(CTX, string.format("Loudness Level %d ##LL%dL", i, i), manager.LoudnessCategories[i])
            if c then manager.LoudnessCategories[i] = v end
        end

        imgui.TextDisabled(CTX, "Integrated Loudness Targets")

        for i = 1, manager.NumLoudnessCategories do
            imgui.SetNextItemWidth(CTX, 100)
            local c, v = imgui.InputInt(CTX, string.format("%s LUFS-I", manager.LoudnessCategories[i] or ("Loudness Level " .. i)), manager.TargetsI[i], 1, 5)
            if c then manager.TargetsI[i] = v end
        end

        imgui.TextDisabled(CTX, "Momentary-Max Loudness Targets")

        for i = 1, manager.NumLoudnessCategories do
            imgui.SetNextItemWidth(CTX, 100)
            local c, v = imgui.InputInt(CTX, string.format("%s LUFS-M", manager.LoudnessCategories[i] or ("Loudness Level " .. i)), manager.TargetsM[i], 1, 5)
            if c then manager.TargetsM[i] = v end
        end

        imgui.Dummy(CTX, 25, breakSize * 2)
        imgui.Text(CTX, "Color Preferences")
        -- imgui.Dummy(CTX, 25, breakSize)
        imgui.TextDisabled(CTX, "Level Colors")
        for i = 1, manager.NumLoudnessCategories do
            local c, v = imgui.ColorEdit4(CTX, string.format("%s Color", manager.LoudnessCategories[i] or ("Level " .. i)), manager.TargetColors[i] or 0x000000FF)
            if c then manager.TargetColors = v end
        end
        imgui.TextDisabled(CTX, "Category Colors")
        local categories = {"LUFS", "Match"}
        for i = 1,  #categories do
            local c, v = imgui.ColorEdit4(CTX, string.format("%s Main Color", categories[i]), manager.CategoryColors[i][1])
            if c then manager.CategoryColors = v end
            local c, v = imgui.ColorEdit4(CTX, string.format("%s Hover Color", categories[i]), manager.CategoryColors[i][2])
            if c then manager.CategoryColors = v end
        end

    end
    imgui.End(CTX)
    if not open then self.showSettings = false manager:SaveMetadata() self.maintainFocus = false end
end

function Gui:Draw()
    local manager = self.manager

    imgui.SetNextWindowSize(CTX, WINDOW_SIZE.width, WINDOW_SIZE.height, imgui.Cond_FirstUseEver)
    local flags = 0 --2048 | imgui.WindowFlags_NoCollapse
    local visible, open = imgui.Begin(CTX, "LUFS Manager", true, flags)
    
    if visible then
        self:DrawMainSection()
        if self.showSettings then
           self:DrawSettingsWindow()
        end
        if self.firstRun then
            manager:LoadMetadata()
            self.firstRun = false
        end
    end
    imgui.End(CTX)

    manager.open = open
    if not manager.open then
        manager:SaveMetadata()
        CTX = nil
    end
end

App = {}
App.__index = App
function App:new()
    local instance = setmetatable({}, App)
    instance.manager = LUFSManager:new()
    instance.gui = Gui:new(instance.manager)
    instance.project = nil
    instance.projectName = nil
    return instance
end

function App:Run()
    if not self.project then
        self.project, self.projectName = reaper.EnumProjects(-1)
    else
        local p, pn = reaper.EnumProjects(-1)
        if self.project ~= p or self.projectName ~= pn then
            self.gui.firstRun = true
            self.manager.unsavedSession = false
            self.project = p
            self.projectName = pn
        end
    end
    self.gui:Draw()
    if not self.gui.maintainFocus then
        local main_hwnd = reaper.GetMainHwnd()
        if main_hwnd then
            reaper.JS_Window_SetFocus(main_hwnd)
        end
        self.gui.maintainFocus = true
     end
    if self.manager.open then
        reaper.defer(function() self:Run() end)
    end
    if self.gui.refreshMatch then
        self.gui.refreshMatch = false
        self.manager:SaveMetadata()
        reaper.Main_OnCommand(self.manager.RefreshMatchAction, 0)
        self.manager:LoadMetadata()
        end
end

local app = App:new()
app:Run()