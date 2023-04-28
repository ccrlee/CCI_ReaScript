-- @description Add Volume Points
-- @author William N. Lowe
-- @version 0.98
-- @about
--   # Add Volume Points
--   Sets a point at edit cursor for selected item or first item under edit cursor. Then sets a point before and after. Uses the GUI companion script to set new times. 
--
--   ## Must have this and GUI script in same folder

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


reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_TAKEENV1"), 0)
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

--[OLD, using Edit Cursor] local time = reaper.GetCursorPosition() - itemPosition

--Msg(reaper.BR_PositionAtMouseCursor(false))

local time = reaper.BR_PositionAtMouseCursor(false) - itemPosition

local numPoints = reaper.CountEnvelopePoints(volumeEnvelope)

reaper.Main_OnCommand(40769, 0)

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

    reaper.PreventUIRefresh(1)

    reaper.InsertEnvelopePoint(volumeEnvelope, middlePointReference[1], middlePointReference[2], shape, ten, true, true)
    reaper.Envelope_SortPoints(volumeEnvelope)

    reaper.InsertEnvelopePoint(volumeEnvelope, prePointReference[1], prePointReference[2], shape, ten, false, true)
    reaper.Envelope_SortPoints(volumeEnvelope)
        
    -- check if point btween this point and mid point
    midPtIndex = reaper.GetEnvelopePointByTime(volumeEnvelope, middlePointReference[1])
    ret, pointTime, level, shape, ten, sel = reaper.GetEnvelopePoint(volumeEnvelope, midPtIndex-1)
    if pointTime > prePointReference[1] then reaper.DeleteEnvelopePointEx(volumeEnvelope, -1, reaper.GetEnvelopePointByTime(volumeEnvelope, prePointReference[1])) end

    -- reset pt index
    midPtIndex = reaper.GetEnvelopePointByTime(volumeEnvelope, middlePointReference[1])

    Msg(midPtIndex)
    -- Msg(pointTime)
    Msg(reaper.GetEnvelopePointByTime(volumeEnvelope, postPointReference[1]))

    -- check if there is a point between midpoint and post point
    if reaper.GetEnvelopePointByTime(volumeEnvelope, postPointReference[1]) <= midPtIndex then
        reaper.InsertEnvelopePoint(volumeEnvelope, postPointReference[1], postPointReference[2], shape, ten, false, true)
        reaper.Envelope_SortPoints(volumeEnvelope)
    end

    reaper.PreventUIRefresh(-1)
else
    ret, pointTime, level, shape, ten, sel = reaper.GetEnvelopePoint(volumeEnvelope, 0)
    if sel then reaper.SetEnvelopePoint( volumeEnvelope, 0, pointTime, level, shape, ten, false) end

    reaper.PreventUIRefresh(1)

    reaper.InsertEnvelopePoint(volumeEnvelope, time, level, shape, ten, true, true)
    reaper.InsertEnvelopePoint(volumeEnvelope, time - tonumber(preTime), level, shape, ten, false, true)
    reaper.InsertEnvelopePoint(volumeEnvelope, time + tonumber(postTime), level, shape, ten, false, true)
    reaper.Envelope_SortPoints(volumeEnvelope)

    reaper.PreventUIRefresh(-1)
end

    reaper.Main_OnCommand(40769, 0)
    reaper.SetMediaItemSelected( item, true)

reaper.SetMediaItemTakeInfo_Value( take, "D_PLAYRATE", itemRate)
reaper.Undo_EndBlock("Add Volume Points", 0)