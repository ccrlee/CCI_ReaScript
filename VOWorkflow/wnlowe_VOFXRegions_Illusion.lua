-- @description VOFX region maker
-- @author William N. Lowe
-- @version 0.7
-- @changelog
--   # Fixed linking bugs

-- local VSDEBUG
-- local s, r = pcall(function()
--         VSDEBUG = dofile("C:\\Users\\ccuts\\.vscode\\extensions\\antoinebalaine.reascript-docs-0.1.15\\debugger\\LoadDebug.lua")
--     end)


local OSWIN = reaper.GetOS():match("Win")
local SLASH = OSWIN and "\\" or "/"
local PROJECT = reaper.GetProjectPath("")
local METAPATH = PROJECT.. SLASH .."LoudnessSettings.lua"
local METADATA = nil

----------------------------------------------------------
----------------------------------------------------------
--HELPERS
----------------------------------------------------------
----------------------------------------------------------
local function Msg(variable)
    local dbug = false
    if dbug then reaper.ShowConsoleMsg(tostring (variable).."\n") end
end

local function GetRenderTrack(parentRegion)
    local ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(parentRegion)

    return  reaper.EnumRegionRenderMatrix( 0, MarInx, 0 )
end

local VOFX_MODES = {
    ["Letters"] = function(fn, idx)
            local str = fn:match("([^_]+)$")
            if not tonumber(str) and #str <= 2 then
                fn = fn:match("(.*)_")
            end
            return string.format("%s_%s", fn, string.char(64 + idx + 1))

        end,
        ["Numbers"] = function(fn, idx)
            local fIdx = tonumber(fn:match("_([^_]*)$"))
            if fIdx then
                --replace index already at end
                idx = idx + fIdx
                local str = fn:match("(.*)_")
                return string.format("%s_%02d", str, idx)
            else
                return string.format("%s_%02d", fn, idx + 1)
            end
        end,
        ["Num_Char"] = function(fn, idx)
            local charName = fn:match("([^_]+)$")
            fn = fn:match("(.*)_")
            local idxOff = tonumber(fn:match("([^_]+)$"))
            fn = fn:match("(.*)_")
            if idxOff then
                return string.format("%s_%02d_%s", fn, idx + idxOff, charName)
            else
                return string.format("%s_%02d_%s", fn, idx + 1, charName)
            end
        end
}

----------------------------------------------------------
----------------------------------------------------------
--FUNCTIONS
----------------------------------------------------------
----------------------------------------------------------

local function loadMetadata()
    local r = reaper.file_exists(METAPATH)
    if not r then reaper.ShowMessageBox("Loudness Settings file not found!", "Script Error", 0) return false end

    local content, d = dofile(METAPATH)
    if content then METADATA = content end
end

local function findRegion(marks, regs, beginning, last)
    local relReg = {}
    for i = 0, (regs + marks) do
        local ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(i)
        local selection = 0
        if isr and regPos <= beginning and regEnd >= last then
            selection = selection + 1
            --table.insert(relReg, i)    --reaper.SetProjectMarker(MarInx, true, beginning, last, regName)
        end
        if isr and regPos >=beginning and regPos <= last then
            selection = selection + 1
        end
        if isr and regEnd >= beginning and regEnd <= last then
            selection = selection + 1
        end
        if selection > 0 then table.insert(relReg, i) end
    end
    local parentRegion = nil
    if #relReg > 1 then
        local ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(relReg[1])
        local compStart = math.abs(regPos - beginning)
        local compEnd = math.abs (regEnd - last)
        local compTotal = compStart + compEnd
        local choice = 1
        for i = 2, #relReg do
            ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(relReg[i])
            local curStart = math.abs(regPos - beginning)
            local curEnd = math.abs (regEnd - last)
            local curTotal = curStart + curEnd
            if curTotal < compTotal then
                choice = i
                compTotal = curTotal
                compStart = curStart
                compEnd = curEnd
            end
        end
        parentRegion = relReg[choice]
    else
        parentRegion = relReg[1]
    end

    return parentRegion
end

local function GetRegionName(filename, index)
    local modesTable = VOFX_MODES
    local modes = {}
    for k, _ in pairs(modesTable) do
        table.insert(modes, k)
    end
    local selectedMode = tonumber(METADATA["VOFXSel"]) + 1
    return VOFX_MODES[METADATA["VOFXModes"][selectedMode]](filename, index)
end

----------------------------------------------------------
----------------------------------------------------------
--MAIN SCRIPT
----------------------------------------------------------
----------------------------------------------------------

loadMetadata()

local numItems = reaper.CountSelectedMediaItems(0)
local allItems = {}
local fileName = ""
for i = 0, numItems do
    allItems[i] = reaper.GetSelectedMediaItem(0, i)
end

local ret, marks, regs = reaper.CountProjectMarkers(0)
local beginning =  reaper.GetMediaItemInfo_Value( allItems[0], "D_POSITION" )
local last =  reaper.GetMediaItemInfo_Value( allItems[numItems - 1], "D_POSITION" ) + reaper.GetMediaItemInfo_Value( allItems[numItems - 1], "D_LENGTH" )

--FIND CORRECT REGION
local parentRegion = findRegion(marks, regs, beginning, last)

local ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(parentRegion)
fileName = tostring(regName)

local ltStart, ltEnd = reaper.GetSet_LoopTimeRange( true, false, regEnd + 0.1, regEnd + 0.1 + #allItems, false )
reaper.Main_OnCommand(40200, 0) -- Time selection: Insert empty space at time selection (moving later items)

for j = #allItems, 0, -1 do
    local _start =  reaper.GetMediaItemInfo_Value( allItems[j], "D_POSITION" )
    reaper.SetMediaItemInfo_Value( allItems[j], "D_POSITION", _start + j )
end

RenderTrack = GetRenderTrack(parentRegion)
local markRegs = regs + marks

for j = 0, #allItems do
    local _start =  reaper.GetMediaItemInfo_Value( allItems[j], "D_POSITION" )
    local _end =  reaper.GetMediaItemInfo_Value( allItems[j], "D_LENGTH" ) + _start
    local newMarker = reaper.AddProjectMarker( 0, true, _start, _end, GetRegionName(fileName, j), markRegs + j ) --defs[METADATA.VOFXModes]['func'](fileName, j)
    reaper.SetProjectMarker(MarInx, true, beginning, _end, regName)
    if RenderTrack ~= nil then reaper.SetRegionRenderMatrix( 0, newMarker, RenderTrack, 1 ) end
end

reaper.DeleteProjectMarker( 0, MarInx, true )
