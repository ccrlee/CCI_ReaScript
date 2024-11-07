-- @description DISC Session Prep script
-- @author Roc Lee / William Loewe
-- @version 1.0

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


function Msg (param)
    reaper.ShowConsoleMsg(tostring (param).."\n")
end
----------------------------------------------------------
--CSV Prep
----------------------------------------------------------
function ReadCsv(CsvTable)
    r, csv = reaper.JS_Dialog_BrowseForOpenFiles( "Library Helper CSV", "Downloads", "Library Metadata Template.csv", "CSV\0*.csv", false )
    if r < 1 then reaper.ReaScriptError( "!No CSV was selected" ) end

    --fileOutput = {}
    local file = assert(io.open(csv, "r"))
    for line in file:lines() do
        fields = line:split(',')
        table.insert(CsvTable, fields)
    end
    file:close()
end
----------------------------------------------------------
--BODY
----------------------------------------------------------
-- Read CSV
CsvTable = {}
ReadCsv(CsvTable)

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
--Space out items
local numItems = reaper.CountSelectedMediaItems(0)
for i = 1, numItems - 1 do
    local item = reaper.GetMediaItem( 0, i )
    local previousItem = reaper.GetMediaItem(0, i - 1)
    local previousStart = reaper.GetMediaItemInfo_Value(previousItem, "D_POSITION")
    local previousLength = reaper.GetMediaItemInfo_Value(previousItem, "D_LENGTH")
    local newStart = previousStart + previousLength + 1
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", newStart)
end


for row = 2, #CsvTable do
    -- Msg("Row "..row)
    local takeCount = 1
    for cell = 1, #CsvTable[row] do
        local takeNumber = CsvTable[row][cell]
        if takeNumber ~= nil then takeNumber = takeNumber:sub(1,-2) end
        
        if tonumber(takeNumber) == nil then goto continue end

            for i = 0, numItems - 1 do
                local item = reaper.GetMediaItem( 0, i )
                local start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local take = reaper.GetTake(item, 0)
                local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                name = name:gsub(".wav", "")
                name = name:gsub(".WAV", "")
                selectTakeNum = name:split("_")
                selectTakeNum = selectTakeNum[#selectTakeNum]

                if tonumber(takeNumber) == tonumber(selectTakeNum) then
                     -- Make region with name
                    local paddingDigit = ""
                    if takeCount < 10 then paddingDigit = "0" end

                    length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                    reaper.AddProjectMarker(0, true, start, start + length, CsvTable[row][1].."_"..paddingDigit..takeCount, 0)
                    reaper.AddProjectMarker(0, false, start, start, CsvTable[row][cell], 0)
                    takeCount = takeCount + 1
                    
                    -- ((add note with line?))
                    note = CsvTable[row][cell+1]
                    _, note = reaper.GetSetMediaItemInfo_String( item, "P_NOTES", note, true )
                end
            end

        ::continue::
    end
end

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock( "Prep Session from CSV", 0)
