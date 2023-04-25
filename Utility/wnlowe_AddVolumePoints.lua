-- @version 0.6
--[[
 * ReaScript Name: wnlowe_AddVolumePoints
 * Author: William N. Lowe
 * Licence: GPL v3
 * REAPER: 6.78
 * Extensions: rtk
 * Version: 0.6
--]]
 
--[[
 * Changelog:
 * v0.6 (2023-04-25)
  + Updated Metadata
 * v0.5 (2023-04-25)
 	+ Initial Release
--]]

----------------------------------------------------------------
----------------------------------------------------------------
-- DEPENDENCIES
----------------------------------------------------------------
----------------------------------------------------------------

-- RTK UI
-- https://reapertoolkit.dev/index.xml

----------------------------------------------------------------
----------------------------------------------------------------
-- GLOBAL HELPER FUNCTIONS AND CONFIG
----------------------------------------------------------------
----------------------------------------------------------------
--Debug Message Function
function Msg(variable)
    dbug = false
    if dbug then reaper.ShowConsoleMsg(tostring (variable).."\n") end
end
--File or Directory helper functions
function exists(file)
    local ok, err, code = os.rename(file, file)
    if not ok then
        if code == 13 then
            return true
        end
    end
    return ok
end
function isdir(path)
    return exists(path.."/")
end

--CSV Helper function from https://nocurve.com/2014/03/05/simple-csv-read-and-write-using-lua/
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
local finalPath = reaper.GetResourcePath() .. '/Scripts/'
local filename = "wnlowe_AddVolumePoints.csv"
local csv = finalPath..filename
local fileOutput = {}
local needNew = true
if exists(csv) then
    local file = assert(io.open(csv, "r"))
    for line in file:lines() do
        fields = line:split(',')
        table.insert(fileOutput, fields)
    end
    file:close()
    needNew = false
end

if #fileOutput > 0 then
    preTime = fileOutput[1][1]
    postTime = fileOutput[1][2]
else
    preTime = 0.160
    postTime = 0.160
end

----------------------------------------
----------------------------------------
--UI
----------------------------------------
----------------------------------------
--UI Config
----------------------------------------
package.path = reaper.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
local rtk = require('rtk')
local log = rtk.log
--Main Window
win = rtk.Window{w=640, h=200, halign = 'center', title='wnl_Add Volume Points'}
--Vertical Primary Container
local vert = win:add(rtk.VBox{halign='center', spacing = 10})
local main = vert:add(rtk.HBox{valign="center", spacing = 10, padding=20})

local preContainer = main:add(rtk.VBox{halign="center", vspacing = 20})
local preText = preContainer:add(rtk.Text{"Pre point Offset:", halign = 'center', hpadding=20})
local pre = preContainer:add(rtk.Entry{placeholder=tostring(preTime), textwidth=5})

local postContainer = main:add(rtk.VBox{halign='center', vspacing = 20})
local postText = postContainer:add(rtk.Text{"Post point Offset:", halign = 'center'})
local post = postContainer:add(rtk.Entry{placeholder=tostring(postTime), textwidth=5})

local defaultCheckContainer = vert:add(rtk.HBox{valign='center',hspacing=20})
local defaultCheckText = defaultCheckContainer:add(rtk.Text{"Set as new Defauls?", textwidth=15})
local defaultCheck = defaultCheckContainer:add(rtk.CheckBox{value='unchecked'})



function closestPoints(arr, num, targetTime)
    local closeBefore = 0
    local beforeDist = targetTime
    local closeAfter = num - 1
    local afterDist = arr[num - 1][1] - targetTime
    if afterDist < 0 then return {[1] = targetTime, [2] = arr[num - 1][2]} end
    for i = 1, num - 2 do
        ret, pointTime, level, shape, ten, sel = reaper.GetEnvelopePoint(volumeEnvelope, i)
        local difference = targetTime - arr[i][1]
        if difference > 0 then
            difference = math.abs(difference)
            if difference < beforeDist then
                closeBefore = i
                beforeDist = difference
            end
        else
            difference = math.abs(difference)
            if difference < afterDist then
                closeAfter = i
                afterDist = difference
            end
        end
    end
    local finalLevel = (arr[closeBefore][2] + arr[closeAfter][2]) / 2
    return {[1] = targetTime, [2] = finalLevel}
end

local complete = vert:add(rtk.Button{label='Execute', fontscale=2})
complete.onclick = function()
    reaper.PreventUIRefresh( 1 )
    numItems = reaper.CountSelectedMediaItems(0)
    if numItems < 1 then
        local numberTracks = reaper.CountSelectedTracks(0)
        for i = 0, numberTracks - 1 do
            reaper.Main_OnCommand(reaper.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX"), 0)
            item = reaper.GetSelectedMediaItem(0, 0)
            if item ~= nil then break end
        end
    end
    item = reaper.GetSelectedMediaItem(0, 0)
    take = reaper.GetActiveTake(item)
    volumeEnvelope = reaper.GetTakeEnvelopeByName(take, "Volume")
    reaper.Undo_BeginBlock()
    local itemPosition = reaper.GetMediaItemInfo_Value( item, "D_POSITION" )
    local itemRate = reaper.GetMediaItemTakeInfo_Value( take, "D_PLAYRATE")
    reaper.SetMediaItemTakeInfo_Value( take, "D_PLAYRATE", 1 )
    local time = reaper.GetCursorPosition() - itemPosition
    local numPoints = reaper.CountEnvelopePoints(volumeEnvelope)
    local preValue = tonumber(pre.value)
    local postValue = tonumber(post.value)
    if preValue ~= nil then preTime = preValue end
    if postValue ~= nil then postTime = postValue end

    if numPoints > 1 then
        pointTimes = {}
        for i = 0, numPoints - 1 do
            ret, pointTime, level, shape, ten, sel = reaper.GetEnvelopePoint(volumeEnvelope, i)
            if sel then reaper.SetEnvelopePoint( volumeEnvelope, 0, pointTime, level, shape, ten, false) end
            pointTimes[i] = {[1] = pointTime, [2] = level}
        end
        middlePointReference = closestPoints(pointTimes, numPoints, time)
        prePointReference = closestPoints(pointTimes, numPoints, time - tonumber(preTime))
        postPointReference = closestPoints(pointTimes, numPoints, time + tonumber(postTime))
        reaper.InsertEnvelopePoint(volumeEnvelope, middlePointReference[1], middlePointReference[2], shape, ten, true, true)
        reaper.InsertEnvelopePoint(volumeEnvelope, prePointReference[1], prePointReference[2], shape, ten, false, true)
        reaper.InsertEnvelopePoint(volumeEnvelope, postPointReference[1], postPointReference[2], shape, ten, false, true)
        reaper.Envelope_SortPoints(volumeEnvelope)
    else
        ret, pointTime, level, shape, ten, sel = reaper.GetEnvelopePoint(volumeEnvelope, 0)
        if sel then reaper.SetEnvelopePoint( volumeEnvelope, 0, pointTime, level, shape, ten, false) end
        reaper.InsertEnvelopePoint(volumeEnvelope, time, level, shape, ten, true, true)
        reaper.InsertEnvelopePoint(volumeEnvelope, time - tonumber(preTime), level, shape, ten, false, true)
        reaper.InsertEnvelopePoint(volumeEnvelope, time + tonumber(postTime), level, shape, ten, false, true)
        reaper.Envelope_SortPoints(volumeEnvelope)
    end
    if defaultCheck.value == rtk.CheckBox.CHECKED or needNew then
        local file = assert(io.open(csv, "w"))
        file:write(tostring(preTime) .. ',' .. tostring(postTime))
        file:close()
        needNew = false
    end
    reaper.SetMediaItemTakeInfo_Value( take, "D_PLAYRATE", itemRate)
    reaper.Undo_EndBlock("Add Volume Points", 0)
    reaper.PreventUIRefresh( -1 )
end

win:open()
