--[[
Description: Project Arkansas VO Session Creation
Version: 2.3
Author: William N. Lowe
]]

--Print Function
local ifdebug = false
function Msg(variable) if ifdebug then reaper.ShowConsoleMsg(tostring(variable) .. "\n") end end

--Adapt to OS
local computerOS = reaper.GetOS()
if string.find(computerOS, "Win") ~= nil then Slash = "\\"
elseif string.find(computerOS, "OS") ~= nil then Slash = "/" end

--Find Paths
local projectPath = reaper.GetProjectPath() .. Slash
local resourcePath = reaper.GetResourcePath() .. Slash .."Scripts" .. Slash

--Helper Functions
function FileExists(file)
    local ok, err, code = os.rename(file,file)
    if not ok then if code == 13 then return true end end
    return ok
end

IncludeAlts = nil

function string:split(sSeparator, nMax, bRegexp)
    if sSeparator == '' then sSeparator = ',' end
    if nMax and nMax < 1 then nMax = nil end
    local aRecord = {}
    if self:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1
        local nField, nStart = 1, 1
        local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst,nLast = self:find(sSeparator, nStart, bPlain)
            nMax = nMax-1
        end
        aRecord[nField] = self:sub(nStart)
    end
    return aRecord
end

function FindFiles(directory)
    local fileList = {}
    local idx = 0
    local file = reaper.EnumerateFiles(directory, idx)

    while file ~= nil do
        table.insert(fileList, directory .. Slash .. file)
        idx = idx + 1
        file = reaper.EnumerateFiles(directory, idx)
    end

    return fileList
end



local function findCharacter(script)
    local characters = {}
    for i = 2, #script - 1 do
        if i == 2 then table.insert(characters, script[2][characterIdx])
        else
            for _, v in pairs(characters) do
                if script[i][characterIdx] == v then goto continue end
            end
            table.insert(characters, script[i][characterIdx])
            ::continue::
        end
    end
    if #characters > 1 then
        local message = "There are multiple Characters in this spreadsheet, in the next dialog please enter the corresponding number for the character you are making a session for. \n"
        for i = 1, #characters do
            message = message .. i .. " = " .. characters[i] .. "\n"
        end
        local int = reaper.ShowMessageBox(message, "Multiple Characters", 0 )
        local r, input = reaper.GetUserInputs( "Select Character", 2, "Character Index, Include Alts", "" )
        Msg(input)
        local characterInx = input:split(',')
        if string.lower(characterInx[2]) == "y" then IncludeAlts = true else IncludeAlts = false end
        if r then return characters[tonumber(characterInx[1])], IncludeAlts else return 2328, IncludeAlts end
    else
        local r, alt = reaper.GetUserInputs( "Include Alts?", 1, "Include Alts", "" )
        if string.lower(alt) == "y" then IncludeAlts = true else IncludeAlts = false end
        return characters[1], IncludeAlts
    end
end

local function handleAlts(row, rowcharacter, sourceFiles)
    local scriptAlts = row[altsIdx]
    if scriptAlts == nil or scriptAlts == "" then return end
    -- scriptAlts = scriptAlts .. ','
    local alts = scriptAlts:split(',')
    if #alts == 0 then return end
    Msg(#alts)
    for a = 1, #alts do
        local altTakeNumber, z = string.match(alts[a], "(%d+)([a-zA-Z]*)")
        if altTakeNumber == nil then goto again end

        Msg("///////////////////////////////////// \n" .. altTakeNumber)
        for b = 1, #sourceFiles do
            local fileTakeNumber, y = string.match(sourceFiles[b], "_(%d+)([a-zA-Z]?)%.wav")
            if tonumber(altTakeNumber) == tonumber(fileTakeNumber) then
                Msg("Hello")
                reaper.InsertMedia(sourceFiles[b], 0)
                reaper.MoveEditCursor(1, false)
                local item = reaper.GetMediaItem( 0, reaper.CountMediaItems(0) - 1 )
                reaper.SetMediaItemSelected(item , false )
                local itemStart = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
                local itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
                local fileName = row[filenameIdx]:match("(.*)%.wav")
                local baseName, suffix = fileName:match("(.+)(_enus.+)")
                local marker = reaper.AddProjectMarker( 0, true, itemStart, itemEnd, baseName .. "_v" .. a .. suffix, -1 )
                local track = reaper.GetSelectedTrack(0, 0)
                reaper.SetRegionRenderMatrix( 0, marker, track, 1 )
                local retval, stringNeedBig = reaper.GetSetMediaTrackInfo_String( track, "P_NAME", rowcharacter, true )
                local retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( item, "P_NOTES", row[lineIdx], true )
                reaper.AddProjectMarker( 0, false, itemStart, itemEnd, alts[a], -1 )
            end
        end
        ::again::
    end
end

-- local function findRow(take, script)
--     -- Msg(#script)
--     for i = 2, #script - 1 do
--         -- Msg(script[i][selectIdx])
--         local rowTakeNumber, rowTakeLetter = string.match(script[i][selectIdx], "(%d+)([a-zA-Z]*)")
--         if rowTakeLetter ~= nil then
--             local rowTake = rowTakeNumber .. string.upper(rowTakeLetter)
--         else local rowTake = rowTakeNumber
--         end
        
--         if rowTake == take then return i end
--     end
-- end


-- local track = reaper.GetSelectedTrack(0, 0)
-- local fx = reaper.TrackFX_GetCount( track )
-- if fx ~= 4 then reaper.ShowMessageBox("Incorrect Track Selected.", "Faliure", 0) goto endOfScript end

local r, csv = reaper.JS_Dialog_BrowseForOpenFiles("Open Script CSV", projectPath, "", "", false)
local r, directory = reaper.JS_Dialog_BrowseForFolder("Audio Files Directory", projectPath)

-- Msg(csv)

local script = {}
local file = assert(io.open(csv, "r"))
for line in file:lines() do
    local fields = line:split('\t')
    table.insert(script, fields)
end
file:close()

characterIdx, filenameIdx, selectIdx, lineIdx, altsIdx = nil, nil, nil, nil, nil
local scriptWidth = #script[1]
for i = 1, scriptWidth do
    -- Msg(script[1][i] .. " - " .. i)
    local head = string.gsub(script[1][i], "^%s*(.-)%s*$", "%1")
    Msg(head)
    if head == "Character" then characterIdx = tonumber(i) -- Msg("Hey")
    elseif head == "Wav Filename" then filenameIdx = tonumber(i) -- Msg("Hi")
    elseif head == "Select" then selectIdx = tonumber(i) -- Msg("Hello")
    elseif head == "Line" then lineIdx = tonumber(i) -- Msg("ahoy")
    elseif head == "Select Alt" or head == "ALT Selects" or head == "Alt" then altsIdx = tonumber(i) -- Msg("Alts here")
    end
end

local char, includeAlts = findCharacter(script)
IncludeAlts = includeAlts
-- if char == 2328 then goto cancel end

for i = 2, #script - 1 do
    if script[i][selectIdx] ~= nil then script[i][selectIdx] = script[i][selectIdx]:gsub(" ", "") end
end


local sourceFiles = {}
sourceFiles = FindFiles(directory)
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
function string_diff(str1, str2)
  if str1 == str2 then
    return "Strings are identical."
  end

  local diff = ""
  for i = 1, math.min(string.len(str1), string.len(str2)) do
    if string.sub(str1, i, i) ~= string.sub(str2, i, i) then
      diff = diff .. "Character at index " .. i .. ": '" .. string.sub(str1, i, i) .. "' in str1 vs. '" .. string.sub(str2, i, i) .. "' in str2\n"
    end
  end

  if string.len(str1) < string.len(str2) then
    diff = diff .. "str2 has " .. string.len(str2) - string.len(str1) .. " extra characters at the end.\n"
  elseif string.len(str1) > string.len(str2) then
    diff = diff .. "str1 has " .. string.len(str1) - string.len(str2) .. " extra characters at the end.\n"
  end

  return diff
end

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- Msg('||' .. string_diff(string.gsub(script[1][16], "^%s*(.-)%s*$", "%1"), "Alts") .. '||')

--Msg(script[1][16])
--if string.gsub(script[1][16], "^%s*(.-)%s*$", "%1") == "Alts" then Msg("william") else Msg("cass") end
-- Msg(#sourceFiles)

-- Go through each file in the user specified source directory
-- for i = 1, #sourceFiles do
--     -- get just the take number
    
    -- local matchRow = findRow(sourceTake, script)
--     if matchRow ~= nil then Msg(matchRow) end
-- end

local nilCount = 0

for i = 1, #script do
    -- Msg(script[i][characterIdx])
    if script[i][characterIdx] == char then
        -- Msg(script[i][selectIdx])
        if script[i][selectIdx] == nil then goto skip end
        for j = 1, #sourceFiles do
            local sourceTakeNumber, sourceTakeLetter = string.match(sourceFiles[j], "_(%d+)([a-zA-Z]?)%.wav")
            -- local sourceTake = sourceTakeNumber .. string.upper(sourceTakeLetter)
            local rowTakeNumber, rowTakeLetter = string.match(script[i][selectIdx], "(%d+)([a-zA-Z]*)")
            -- local rowTake = rowTakeNumber .. string.upper(rowTakeLetter)
            if rowTakeNumber == nil then goto skip end
            if tonumber(rowTakeNumber) < 10 then rowTakeNumber = "0" .. rowTakeNumber end
            if sourceTakeNumber == rowTakeNumber then
                reaper.InsertMedia(sourceFiles[j], 0)
                reaper.MoveEditCursor(1, false)
                local item = reaper.GetMediaItem( 0, reaper.CountMediaItems(0) - 1 )
                reaper.SetMediaItemSelected(item , false )
                local itemStart = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
                local itemEnd = itemStart + reaper.GetMediaItemInfo_Value( item, "D_LENGTH" )
                local fileName = string.gsub(script[i][filenameIdx], "^%s*(.-)%s*$", "%1")
                local marker = reaper.AddProjectMarker( 0, true, itemStart, itemEnd, fileName, -1 )
                local track = reaper.GetSelectedTrack(0, 0)
                reaper.SetRegionRenderMatrix( 0, marker, track, 1 )
                if char ~= nil then local retval, stringNeedBig = reaper.GetSetMediaTrackInfo_String( track, "P_NAME", char, true )
                else nilCount = nilCount + 1 end
                local retval, stringNeedBig = reaper.GetSetMediaItemInfo_String( item, "P_NOTES", script[i][lineIdx], true )
                reaper.AddProjectMarker( 0, false, itemStart, itemEnd, script[i][selectIdx], -1 )
                reaper.AddProjectMarker( 0, false, itemStart + 0.5, itemEnd, script[i][lineIdx], -1 )
                -- Msg(script[i][altsIdx])
                Msg(IncludeAlts)
                if IncludeAlts then handleAlts(script[i], char, sourceFiles) end
                -- handleAlts(script[i], char, sourceFiles)
            end
        end
        ::skip::
    end
end

if nilCount > 0 then reaper.ShowMessageBox( "Note: there was no character found in the spreadsheet, but the script was successful. There were " .. nilCount .. " instances of this.", "No Character Found", 0) end
-- reaper.InsertMedia( file, 0 )




-- ::endOfScript::
reaper.ThemeLayout_RefreshAll()
