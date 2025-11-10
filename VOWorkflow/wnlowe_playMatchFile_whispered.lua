-- @description Plays a match file from an assigned folder's "Whispered" subdirectory
-- @author William N. Lowe
-- @version 0.95

-- local VSDEBUG = dofile("C:\\Users\\ccuts\\.vscode\\extensions\\antoinebalaine.reascript-docs-0.1.15\\debugger\\LoadDebug.lua")

local LOUDNESS = "whispered"
local PROJECT = reaper.GetProjectPath("")
local METADATA = PROJECT.."/LoudnessSettings.lua"
local OSWIN = reaper.GetOS():match("Win")
local SLASH = OSWIN and "\\" or "/"
local FOLDERS, FULL_FILES, REF_TRACK, FILES


--HELPER FUNCTIONS
local ifdebug = true
function Msg(variable) if ifdebug then reaper.ShowConsoleMsg(tostring(variable) .. "\n") end end

--
local function FindAction(actionName)
    local section = 0
    local i = 0
    repeat
        local r, name = reaper.kbd_enumerateActions(section, i)
        if r and r ~= 0 and actionName == name then return r end
        i = i + 1
    until not r or r == 0

    reaper.ShowMessageBox("Action " .. actionName .. " Could Not be Found!", "Script Error", 0) return 0
end

-- MAIN FUNCTIONS
local function loadData()
    local r = reaper.file_exists(METADATA)
    if not r then reaper.ShowMessageBox("Loudness Settings file not found!", "Script Error", 0) return false end

    local m, directories = dofile(METADATA)

    -- FOLDERS = directories["folders"]
    FULL_FILES = directories["files"]
    local trackGUID = directories["referenceTrack"]
    REF_TRACK = reaper.BR_GetMediaTrackByGUID(0, trackGUID)

    local character = directories["character"]
    if character ~= "All" then
        local fileParent = FULL_FILES["characters"][character]
        FILES = fileParent[LOUDNESS]
    else
        FILES = FULL_FILES[LOUDNESS]
    end

end

reaper.CF_Preview_StopAll()
loadData()

local lineSelection = math.random(#FILES)

Msg("Selected file: " .. FILES[lineSelection])

Msg("File exists: " .. tostring(reaper.file_exists(FILES[lineSelection])))

local source = reaper.PCM_Source_CreateFromFile( FILES[lineSelection] )
Msg("Source: " .. tostring(source))

if not source then
    reaper.ShowMessageBox("Failed to create PCM source from file!", "Error", 0)
    return
end

local preview = reaper.CF_CreatePreview( source )
Msg("Preview: " .. tostring(preview))

if not preview then
    reaper.ShowMessageBox("Failed to create preview!", "Error", 0)
    return
end

Msg("REF_TRACK: " .. tostring(REF_TRACK))

if REF_TRACK then
    local r = reaper.CF_Preview_SetOutputTrack( preview, 0, REF_TRACK )
    Msg("SetOutputTrack result: " .. tostring(r))
end

-- local r = reaper.CF_Preview_SetOutputTrack( preview, 0, track )
local r = reaper.CF_Preview_Play( preview )
