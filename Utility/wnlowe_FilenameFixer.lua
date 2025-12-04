-- @description wnlowe Filename Fixer
-- @about Creates a directory with txt files that share filenames with your project region names to use Power Rename to rename regions
-- @author William N. Lowe
-- @version 0.10

local USEROSWIN = reaper.GetOS():match("Win")
local SLASH = USEROSWIN and "\\" or "/"
local projectPath = reaper.GetProjectPath()
local numRegions = reaper.CountProjectMarkers(0)
local destinationPath = projectPath .. SLASH .. "FileRenaming" .. SLASH
local regionNames = {}

local function Msg(variable)
    local dbug = true
    if dbug then reaper.ShowConsoleMsg(tostring(variable).."\n") end
end

reaper.RecursiveCreateDirectory(destinationPath, 0)

for i = 0, numRegions do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
    if retval and isrgn then
        regionNames[markrgnindexnumber] = name
        -- Msg(name)
    end
end

for k, v in pairs(regionNames) do
    local filename = string.format("%s%s_%s.txt", destinationPath, tostring(k), v)
    Msg(filename)
    local file = io.open(filename, "w")
    if not file then return end
    file:write("")
    file:close()
end

reaper.ShowMessageBox(string.format("Now manipulate your filenames in %s", destinationPath), "Rename Files", 0)

local newFilenames = {}
local i = 0
repeat
    local file = reaper.EnumerateFiles(destinationPath, i)
    if file then
        table.insert(newFilenames, file)
    end
    i = i + 1
until not file


for _, file in ipairs(newFilenames) do
    local key, newValue = file:match("([^_]+)_(.+)")
    newValue = newValue:match("(.+)%.txt$")

    local found = false
    local j = 0
    repeat
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(j)
        if retval and isrgn and markrgnindexnumber == tonumber(key) then
            reaper.SetProjectMarker(markrgnindexnumber, true, pos, rgnend, newValue)
            found = true
        end
        j = j + 1
    until not retval or found

    os.remove(destinationPath .. file)
end