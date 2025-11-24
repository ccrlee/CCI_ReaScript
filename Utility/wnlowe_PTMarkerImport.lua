-- @description PT -> Export as TXT -> Markers only import to REAPER
-- @author William N. Lowe
-- @version 0.1
-- @changelog
--   # Initial Version

local VSDEBUG -- = dofile("C:\\Users\\ccuts\\.vscode\\extensions\\antoinebalaine.reascript-docs-0.1.15\\debugger\\LoadDebug.lua")

local s, r = pcall(function()
        VSDEBUG = dofile("C:\\Users\\ccuts\\.vscode\\extensions\\antoinebalaine.reascript-docs-0.1.15\\debugger\\LoadDebug.lua")
    end)

local USEROSWIN = reaper.GetOS():match("Win")

local function Msg(msg)
    debug = true
    if debug then reaper.ShowConsoleMsg(tostring(msg) .. "\n")end
end

local function GetDownloadsFolder()
    local downloadsPath
    if USEROSWIN then
        downloadsPath = os.getenv("USERPROFILE") .. "\\Downloads\\"
    else
        downloadsPath = os.getenv("HOME") .. "/Downloads/"
    end
    return downloadsPath
end

local function splitLines(str)
  local lines = {}
  for line in str:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  return lines
end

local function splitColumns(tbl, start)
    local newTable = {}
    -- Msg(#tbl)
    for i = start + 1, #tbl do
        local row = tbl[i]
        local newRow = {}
        for col in row:gmatch("[^\t]+") do
            col = col:match("^%s*(.-)%s*$")
            if i == 1 then
                -- Msg(col)
            end
            table.insert(newRow, col)
        end
        table.insert(newTable, newRow)
    end
    return newTable
end

local r, filepath = reaper.GetUserFileNameForRead(GetDownloadsFolder(), "Select TXT File From PT", ".txt")
-- Msg(filepath)
if not r then return end --ERROR OUT
local file = io.open(filepath, "r")
if not file then return end --ERROR OUT
local content = file:read("a")
file:close()

local lines = splitLines(content)
local startingElement = nil
local SAMPLE_RATE
for idx, line in ipairs(lines) do
    if string.match(line, "SAMPLE RATE:") then
        if tonumber(line:match("%d+%.%d+$")) then
            SAMPLE_RATE = tonumber(line:match("%d+%.%d+$"))
        end
    end
    if string.match(line, "LOCATION") and string.match(line, "TIME REFERENCE") and string.match(line, "UNITS") then
        -- Msg(line)
        startingElement = idx
        break
    end
end

local headers = lines[startingElement]
local indexedHeading = {}
for str in headers:gmatch("[^\t]+") do
    table.insert(indexedHeading, str:match("^%s*(.-)%s*$"))
end

if not startingElement then return end --ERROR OUT
-- Msg(startingElement)
-- for i = 1, startingElement do
--     -- Msg(i .. " contains " ..lines[i])
--     table.remove(lines, i)
-- end

lines = splitColumns(lines, startingElement)
-- Msg(lines[1][4])
if lines[1][4] == "Samples" then
    for i, line in ipairs(lines) do
        local seconds = line[3] / SAMPLE_RATE
        reaper.AddProjectMarker(0, false, seconds, seconds, line[5], 100 + i)
    end
end