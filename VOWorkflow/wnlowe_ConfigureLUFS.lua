-- @description Custom GUI Bar for VO Configuration
-- @author William N. Lowe
-- @version 1.09

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

function Msg(msg)
    debug = true
    if debug then reaper.ShowConsoleMsg(tostring(msg) .. "\n")end
end

LUFSManager = {}
LUFSManager.__index = LUFSManager
function LUFSManager:new()
    local instance = setmetatable({}, LUFSManager)
    CTX = imgui.CreateContext("LUFS Manager")
    instance.open = true
    instance.unsavedSession = false

    instance.MetadataFilePath = nil

    instance.WhisperedTargetI = -20
    instance.WhisperedTargetM = -16
    instance.WhisperedOffset = 0

    instance.SpokenTargetI = -18
    instance.SpokenTargetM = -15
    instance.SpokenOffset = 0

    instance.YelledTargetI = -14
    instance.YelledTargetM = -11
    instance.YelledOffset = 0

    instance.CutoffTime = 3

    instance.WhisperedLUFSAction = nil
    instance.SpokenLUFSAction = nil
    instance.YelledLUFSAction = nil
    instance.ShoutedLUFSAction = nil

    instance.WhisperedMatchAction = nil
    instance.SpokenMatchAction = nil
    instance.YelledMatchAction = nil
    instance.ShoutedMatchAction = nil

    instance.RefreshMatchAction = nil
    instance.StopMatchAction = nil

    instance.folders = {}
    instance.files = {}
    instance.referenceTrack = nil
    instance.character = "All"

    return instance
end

function LUFSManager:LoadMetadata()
    local projectPath = reaper.GetProjectPath("")
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
    self.MetadataFilePath = filePath
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
        self.WhisperedOffset = m["Offsets"][1]
        self.SpokenOffset = m["Offsets"][2]
        self.YelledOffset = m["Offsets"][3]
        self.CutoffTime = m["CutoffTime"]
        self.WhisperedTargetI, self.SpokenTargetI, self.YelledTargetI = table.unpack(m["TargetsI"])
        self.WhisperedTargetM, self.SpokenTargetM, self.YelledTargetM = table.unpack(m["TargetsM"])
    end
    if directories then
        local d = directories
        self.folders = d["folders"]
        self.files = d["files"]
        self.referenceTrack = d["referenceTrack"]
        self.character = d["character"]
    end
    self:FindActions()
end

function LUFSManager:FindActions()
    local actionNames = {
        ["Script: wnlowe_lufsSet__shouted.lua"] = function(id) self.ShoutedLUFSAction = id end,
        ["Script: wnlowe_lufsSet__spoken.lua"] = function(id) self.SpokenLUFSAction = id end,
        ["Script: wnlowe_lufsSet__whisper.lua"] = function(id) self.WhisperedLUFSAction = id end,
        ["Script: wnlowe_lufsSet__yelled.lua"] = function(id) self.YelledLUFSAction = id end,
        ["Script: wnlowe_playMatchFile_shouted.lua"] = function(id) self.ShoutedMatchAction = id end,
        ["Script: wnlowe_playMatchFile_spoken.lua"] = function(id) self.SpokenMatchAction = id end,
        ["Script: wnlowe_playMatchFile_whispered.lua"] = function(id) self.WhisperedMatchAction = id end,
        ["Script: wnlowe_playMatchFile_yelled.lua"] = function(id) self.YelledMatchAction = id end,
        ["Script: wnlowe_resetMatchFolder.lua"] = function(id) self.RefreshMatchAction = id end,
        ["Script: wnlowe_stopAllPreviews.lua"] = function(id) self.StopMatchAction = id end
    }
    local section = 0
    local i = 0
    repeat
        local r, name = reaper.kbd_enumerateActions(section, i)
        if r and r ~= 0 and actionNames[name] then actionNames[name](r) end
        i = i + 1
    until not r or r == 0 or (self.ShoutedLUFSAction and self.SpokenLUFSAction and self.WhisperedLUFSAction and self.YelledLUFSAction)
end

function LUFSManager:SerializeMetadata()
    local metadata = {
        TargetsI = {self.WhisperedTargetI, self.SpokenTargetI, self.YelledTargetI},
        TargetsM = {self.WhisperedTargetM, self.SpokenTargetM, self.YelledTargetM},
        Offsets = {self.WhisperedOffset, self.SpokenOffset, self.YelledOffset},
        CutoffTime = self.CutoffTime
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
        local projectPath = reaper.GetProjectPath("")
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

    return instance
end

function Gui:SavedSession()
    local manager = self.manager
    manager.unsavedSession = false
    manager:SaveMetadata()
end

function Gui:DrawMainSection()
    local manager = self.manager
    local inputSize = 560
    local fullSize = imgui.GetContentRegionAvail(CTX)
    local center = fullSize / 2

    -------------- SETTINGS BUTTONS
    if imgui.Button(CTX, "Target Settings", 85, 25) then
        self.showSettings = true
    end

    imgui.SameLine(CTX)
    if imgui.Button(CTX, "Refresh Match", 85, 25) then
        self.refreshMatch = true
    end

    imgui.SameLine(CTX)
    if imgui.Button(CTX, "Stop Match", 70, 25) then
        reaper.Main_OnCommand(manager.StopMatchAction, 0)
    end

    if manager.unsavedSession then
        imgui.SameLine(CTX)
        if imgui.Button(CTX, "Saved Session", 85, 25) then
            self:SavedSession()
        end
    end

    ------------- LUFS BUTTONS
    local numButtons = self.includeScreamed and 4 or 3 --if we are including scremed, 4 buttons, otherwise 3
    imgui.SameLine(CTX)
    local remainingSpace = imgui.GetContentRegionAvail(CTX)
    remainingSpace = remainingSpace - center
    local buttonWidth = 85
    local buttonSpace = buttonWidth * numButtons
    imgui.Dummy(CTX, remainingSpace - buttonSpace, 25)

    imgui.SameLine(CTX)
    if imgui.Button(CTX, "LUFS Whispered", buttonWidth + 10, 25) then
        if manager.WhisperedLUFSAction then reaper.Main_OnCommand(manager.WhisperedLUFSAction, 0)
        else reaper.ShowMessageBox("Action Not Found!", "Script Error", 0) end
        self.maintainFocus = false
    end

    imgui.SameLine(CTX)
    if imgui.Button(CTX, "LUFS Spoken", buttonWidth - 5, 25) then
        if manager.SpokenLUFSAction then reaper.Main_OnCommand(manager.SpokenLUFSAction, 0)
        else reaper.ShowMessageBox("Action Not Found!", "Script Error", 0) end
        self.maintainFocus = false
    end

    imgui.SameLine(CTX)
    if imgui.Button(CTX, "LUFS Yelled", buttonWidth - 5, 25) then
        if manager.YelledLUFSAction then reaper.Main_OnCommand(manager.YelledLUFSAction, 0)
        else reaper.ShowMessageBox("Action Not Found!", "Script Error", 0) end
        self.maintainFocus = false
    end

    if self.includeScreamed then
        imgui.SameLine(CTX)
        if imgui.Button(CTX, "LUFS Screamed", buttonWidth, 25) then
            if manager.ScreamedLUFSAction then reaper.Main_OnCommand(manager.ScreamedLUFSAction, 0)
            else reaper.ShowMessageBox("Action Not Found!", "Script Error", 0) end
            self.maintainFocus = false
        end
    end

    -- MATCH BUTTONS
    imgui.SameLine(CTX)
    if imgui.Button(CTX, "Match Whispered", buttonWidth + 15, 25) then
        reaper.Main_OnCommand(manager.WhisperedMatchAction, 0)
    end

    imgui.SameLine(CTX)
    if imgui.Button(CTX, "Match Spoken", buttonWidth, 25) then
        reaper.Main_OnCommand(manager.SpokenMatchAction, 0)
    end

    imgui.SameLine(CTX)
    if imgui.Button(CTX, "Match Yelled", buttonWidth - 5, 25) then
        reaper.Main_OnCommand(manager.YelledMatchAction, 0)
    end

    if self.includeScreamed then
        imgui.SameLine(CTX)
        if imgui.Button(CTX, "Match Screamed", buttonWidth, 25) then
            reaper.Main_OnCommand(manager.ScreamedLUFSAction, 0)
        end
    end

    ------------ Settings Boxes
    imgui.SameLine(CTX)
    remainingSpace = imgui.GetContentRegionAvail(CTX)
    imgui.Dummy(CTX, remainingSpace - inputSize, 25)

    imgui.SameLine(CTX)
    imgui.SetNextItemWidth(CTX, 100)
    local c, newV = imgui.InputDouble(CTX, "Whisper Offset ##WO", manager.WhisperedOffset, 0.5, 1.0, "%.2f")
    if c then manager.WhisperedOffset = newV manager:SaveMetadata() end

    imgui.SameLine(CTX)
    imgui.SetNextItemWidth(CTX, 100)
    c, newV = imgui.InputDouble(CTX, "SpokenOffset ##SO", manager.SpokenOffset, 0.5, 1.0, "%.2f")
    if c then manager.SpokenOffset = newV manager:SaveMetadata() end

    imgui.SameLine(CTX)
    imgui.SetNextItemWidth(CTX, 100)
    c, newV = imgui.InputDouble(CTX, "YelledOffset ##YO", manager.YelledOffset, 0.5, 1.0, "%.2f")
    if c then manager.YelledOffset = newV manager:SaveMetadata() end
end

function Gui:DrawSettingsWindow()
    local manager = self.manager

    imgui.SetNextWindowSize(CTX, 400, 300, imgui.Cond_FirstUseEver)
    local visible, open = imgui.Begin(CTX, "Settings", true, 2048)

    if visible then
        imgui.Text(CTX, "General Settings")
        imgui.SetNextItemWidth(CTX, 100)
        local c, newV = imgui.InputDouble(CTX, "Cutoff Time between LUFS-M and LUFS-I ##CT", manager.CutoffTime, 0.5, 1.0, "%.2f")
        if c then manager.CutoffTime = newV manager:SaveMetadata() end

        if #manager.folders > 3 then
            local folderCharacters = {"All"}
            for k, v in pairs(manager.folders["characters"]) do
                table.insert(folderCharacters, k)
            end
            local c, v = imgui.Combo(CTX, "Character Match Selection ##CMS", 0, table.concat(folderCharacters, "\0") .. "\0")
            if c then manager.character = v end
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
        reaper.Main_OnCommand(self.manager.RefreshMatchAction, 0)
    end
end

local app = App:new()
app:Run()