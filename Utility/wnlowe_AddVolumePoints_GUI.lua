-- @description Add Volume Points GUI
-- @author William N. Lowe
-- @version 0.5
-- @about
--   # Add Volume Points GUI
--   Sets pre and post times for Add Volume Points script. Can also execute function script from this script. 
--
--   ## Must have GUI and function script in same folder
--   ## Must install rtk dependency

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

function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*[/\\])") or "."
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

local complete = vert:add(rtk.Button{label='Execute', fontscale=2})
complete.onclick = function()
    reaper.PreventUIRefresh( 1 )
    dofile(script_path().."/wnlowe_AddVolumePoints.lua")
    if defaultCheck.value == rtk.CheckBox.CHECKED or needNew then
        local file = assert(io.open(csv, "w"))
        file:write(tostring(preTime) .. ',' .. tostring(postTime))
        file:close()
        needNew = false
    end
    reaper.PreventUIRefresh( -1 )
end

win:open()