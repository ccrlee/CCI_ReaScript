-- @description Constructs Folder and File tables for play mattch file scripts
-- @author William N. Lowe
-- @version 0.91

local VSDEBUG = dofile("C:\\Users\\ccuts\\.vscode\\extensions\\antoinebalaine.reascript-docs-0.1.15\\debugger\\LoadDebug.lua")

local PROJECT = reaper.GetProjectPath("")
local META_PATH = PROJECT.."/LoudnessSettings.lua"
local OSWIN = reaper.GetOS():match("Win")
local SLASH = OSWIN and "\\" or "/"
local FOLDERS, FULL_FILES, META_INFO, REF_TRACK

--HELPER FUNCTIONS
local ifdebug = false
local function Msg(variable) if ifdebug then reaper.ShowConsoleMsg(tostring(variable) .. "\n") end end

local function SerializeTable(tbl, indent)
    indent = indent or 0
    local spaces = string.rep("     ", indent)
    local lines = {}
    table.insert(lines, "{")

    for key,value in pairs(tbl) do
        local keyStr = type(key) == "number" and string.format("[%d]", key) or key
        local valStr
        if type(value) == "table" then
            valStr = SerializeTable(value, indent + 1)
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

local function LoadMetadata()
    local r = reaper.file_exists(META_PATH)
    if not r then return end

    local metadata = nil
    local d = nil
    local status, result = pcall(function()
        META_INFO, d = dofile(META_PATH)
    end)

    if not status or d == nil then return end

    REF_TRACK = d["referenceTrack"]

end

-- SCRIPT FUNCTIONS
local function findDirectory(dir)
    local directory = nil
    if dir == nil then
        local r, d = reaper.JS_Dialog_BrowseForFolder( "Match Files Parent Directory", "G:\\My Drive\\Erebus\\Ref Files" or PROJECT )
        if d == "" then return end
        directory = d
    else
        directory = dir
    end

    local folders = {}

    local i = 0
    repeat
        local folder = reaper.EnumerateSubdirectories(directory, i)
        if folder then table.insert(folders, folder) end --folders[folder] = true
        i = i + 1
    until not folder


    local directories = { whispered = false, spoken = false, yelled = false, shouted = false, characters = {} }
    for _, f in ipairs(folders) do
        if directories[string.lower(f)] ~= nil then
            directories[string.lower(f)] = directory .. SLASH .. f
        else
            directories["characters"][f] = findDirectory(directory .. SLASH .. f)
        end
    end
    return directories
end

local function FindFiles(directory)
    local fileList = {}
    local idx = 0
    local file = reaper.EnumerateFiles(directory, idx)

    while file ~= nil do
        local ext = file:match("^.+(%..+)$")
        if ext ~= ".ini" then table.insert(fileList, directory .. SLASH .. file) end
        idx = idx + 1
        file = reaper.EnumerateFiles(directory, idx)
    end

    return fileList
end

local function getFiles(subTable)
    local files = {}
    local folders = subTable or FOLDERS
    for key, value in pairs(folders) do
        if type(value) == "table" then
            for key2, value2 in pairs(value) do
                files[key2] = getFiles(value2)
            end
        elseif value then
            files[key] = FindFiles(value)
        end
    end
    return files
end

local function findRefTrack()
    local numTracks = reaper.CountTracks(0)
    for i = 0, numTracks do
        local t = reaper.GetTrack(0, i)
        local r, name = reaper.GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
        if name ~= "" and not string.find(name, "Take") then
            return reaper.BR_GetMediaTrackGUID( t )
        end
    end
end

FOLDERS = findDirectory()
FULL_FILES = getFiles()

LoadMetadata()

local directory_info = {folders = FOLDERS, files = FULL_FILES, referenceTrack = findRefTrack(), character = "All"}

local strDirectory = SerializeTable(directory_info)



local strMetadata = META_INFO and SerializeTable(META_INFO) or "{}"

local outputStr = string.format("local metadata = %s local directories = %s return metadata, directories", strMetadata, strDirectory)
local file = io.open(META_PATH, "w")
if not file then return false end
file:write(outputStr)
file:close()