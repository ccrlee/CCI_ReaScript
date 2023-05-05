-- @description Fast Render Window
-- @author William N. Lowe
-- @version 0.5
-- @about
--   # Fast Render Window
--   Script to render audio in a more streamlined manner
--      for very specific workflows. 
--   ## Must have RTK installed
--   wnlsounddesign.com

----------------------------------------------------------------
----------------------------------------------------------------
-- Release Notes
----------------------------------------------------------------
----------------------------------------------------------------
--[[
]]--------------------------------------------------------------
----------------------------------------------------------------
-- To-Do
----------------------------------------------------------------
----------------------------------------------------------------
--[[
    [] GUI Prettification
    [x] Add Ambix Options
    [] Complete NVK Check
    [] Make NVK actions universal
    [x] Close CB replaces to the wrong place
    [] Move close to bottom
]]--------------------------------------------------------------
----------------------------------------------------------------
-- GLOBAL HELPER FUNCTIONS AND CONFIG
----------------------------------------------------------------
----------------------------------------------------------------
--Debug Message Function
function Msg(variable)
    dbug = false
    if dbug then reaper.ShowConsoleMsg(tostring (variable).."\n") end
end

--UltraSchall API Enable
dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
-- ultraschall.ApiTest()

--File or Directory helper functions
function exists(file)
    Msg('File: '.. file)
    local ok, err, code = os.rename(file, file)
    Msg('OK:' .. tostring(ok))
    Msg('Code:' .. tostring(code))
    Msg('Error: ' .. tostring(err))
    if not ok then
        if code == 13 then
            return true
        end
    end
    return ok
end
function isdir(path)
    Msg(path)
    Msg('Response: '..tostring(exists(path.."/")))
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

----------------------------------------------------------------
----------------------------------------------------------------
-- CSV CONFIG AND FUNCTIONS
----------------------------------------------------------------
----------------------------------------------------------------

function WritePaths()
    local file = assert(io.open(csv, "w"))
    if not isdir(defaultRenderDir) then
        local valid = false
        if not isdir(defaultRenderDir) then
            while not valid do
                v, defaultRenderDir = reaper.GetUserInputs("Final Render Output Path", 1, "Final Render Output Path: extrawidth=150", "")
                if not exists(defaultRenderDir) then
                    reaper.ShowMessageBox( "That is not a valid render directory :( Please try again", "Invalid Directory", 0 )
                else valid = true
                    Msg("End")
                end
            end
            Msg("What??")
        end
    end
    local bvalid = false
    Msg('hi')
    while not bvalid do
        Msg("Hello")
        v, pigmentsRenderDir = reaper.GetUserInputs("Pigments Parent Render Path", 1, "Pigments Parent Path: extrawidth=150", "")
        if not isdir(defaultRenderDir) then
            reaper.ShowMessageBox( "That is not a valid pigments directory :( Please try again", "Invalid Directory", 0 )
        else bvalid = true
        end
    end
    file:write("DRD," .. defaultRenderDir ..'\nPigments,' .. pigmentsRenderDir)
    file:close()
end

resources =  reaper.GetResourcePath()
nvkPath = resources .. '/Scripts/nvk-ReaScripts/FOLDER_ITEMS'
validNVK = isdir(nvkPath)
if not validNVK then return end
defaultRenderDir = "E:/OneDrive - Facebook/AW2_zRenders"
pigmentsRenderDir = ''
csv = 'wnlowe_renderScript.csv'
if not exists(csv) then
    WritePaths()
else
    fileOutput = {}
    local file = assert(io.open(csv, "r"))
    for line in file:lines() do
        fields = line:split(',')
        table.insert(fileOutput, fields)
    end
    file:close()
    if #fileOutput < 2 then WritePaths()
    elseif fileOutput[1][2] == '' or fileOutput[2][2] == '' then WritePaths()
    elseif fileOutput[1][1] == nil or fileOutput[2][2] == nil then WritePaths()
    else
        for a = 1, #fileOutput do
            if fileOutput[a][1] == 'DRD' then
                defaultRenderDir = fileOutput[a][2]
            elseif fileOutput[a][1] == 'Pigments' then
                pigmentsRenderDir = fileOutput[a][2]
            end
        end
    end
end

function PigmentsRenderPath(dir)
    if not isdir(dir) then
        while not valid do
            v, pigmentsRenderDir = reaper.GetUserInputs("Pigments Parent Render Path", 1, "Pigments Parent Path: extrawidth=150", "")
            if not isdir(defaultRenderDir) then
                reaper.ShowMessageBox( "That is not a valid directory :( Please try again", "Invalid Directory", 4 )
            else valid = true
            end
        end
    end
    dir = pigmentsRenderDir
    local month = os.date('%b')
    local reqDir = dir..'/'..month
    if not isdir(reqDir) then
        os.execute('mkdir '.. reqDir)
        return reqDir
    else
        return reqDir
    end
end
----------------------------------------------------------------
----------------------------------------------------------------
-- RENDER SETTINGS CONFIG AND GLOBAL
----------------------------------------------------------------
----------------------------------------------------------------

pd = tostring(reaper.GetProjectPath())
projdir = string.sub(pd, 1, (string.len(pd) - 6))
renderdir = defaultRenderDir
wavSettings = ultraschall.CreateRenderCFG_WAV(2, 0, 3, 1, false )
vidSettings =  ultraschall.CreateRenderCFG_QTMOVMP4_Video(2, 100, 2, 1920, 1080, 30, true)
wavSettings32 = ultraschall.CreateRenderCFG_WAV(3, 0, 3, 1, false )
reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 1, true)
-- reaper.AddRemoveReaScript( add, sectionID, scriptfn, commit )

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
win = rtk.Window{w=640, h=480, halign = 'center', title='WNL Render Settings'}
--Vertical Primary Container
local main = win:add(rtk.VBox{halign="center", vspacing = 10})
----------------------------------------
--Mode Selection title and dropdown
----------------------------------------
local selectTitle = main:add(rtk.Text{"Select render type:", halign = "center"})
local selection = main:add(rtk.OptionMenu{
    menu={
        {'NVK Render', id='nvk', color = '#00FFFF'},
        {'Region Matrix', id='rrm'},
        {'Time Selection', id='time'},
        {'UCS Render', id='ucs'},
    },
})
selection:attr('selected', 'nvk')
method = 'nvk'

----------------------------------------
--If NVK Options
----------------------------------------
nh = main:add(rtk.HBox{valign = 'center', hspacing = 20})
function IfNvk()
    nt = nh:add(rtk.Text{"Full NVK Options?", halign = 'center', valign = 'center'})
    fullNVK = nh:add(rtk.CheckBox{value = 'unchecked'})
    nvkExists = true
end
if method == 'nvk' then IfNvk() end
selection.onchange = function(self, item)
    method = item.id
    if method == 'nvk' and not nvkExists then IfNvk()
    elseif method ~= 'nvk' and nvkExists then
        nh:remove_index(1)
        nh:remove_index(1)
        nvkExists = false
    end
end

---------------------------------------------------
--Render Settings
---------------------------------------------------
local renderSettingsContainter = main:add(rtk.VBox{halign='center', spacing = 20, padding = 10})

local ambixSettingsContainer = renderSettingsContainter:add(rtk.HBox{valign='center', spacing=10})
local ambixSettingsText = ambixSettingsContainer:add(rtk.Text{"Quad Channels?"})
local ambixSettingsCB = ambixSettingsContainer:add(rtk.CheckBox{value='unchecked'})

local bitDepthSettingsContainer = renderSettingsContainter:add(rtk.HBox{valign='center', spacing=10})
local bitDepthSettingsText = bitDepthSettingsContainer:add(rtk.Text{"32 Bit Render?"})
local bitDepthSettingsCB = bitDepthSettingsContainer:add(rtk.CheckBox{value='unchecked'})

---------------------------------------------------
--Close Count Settings with Docking Considerations
---------------------------------------------------
close = main:add(rtk.HBox{valign="center", hspacing = 20})
function BuildCB()
    --Question Text
    ct = close:add(rtk.Text{"Close After?", halign = "center", valign = "center"})
    --Checkbox
    cb = close:add(rtk.CheckBox{value = 'checked'})
    cbbool = true
end

BuildCB()

cb.onchange = function(self)
    if cb.value == rtk.CheckBox.UNCHECKED then
        entry = close:add(rtk.Entry{placeholder='0', textwidth=15})
        entry.onkeypress = function(self, event)
            if event.keycode == rtk.keycodes.ESCAPE then
                self:clear()
                self:animate{'bg', dst=rtk.Attribute.DEFAULT}
            elseif event.keycode == rtk.keycodes.ENTER then
                self:animate{'bg', dst='lightgreen'}
            end
        end
    else
        close:remove_index(3)
    end
end

win.ondock = function()
    if win.docked then
        if cbbool then
            close:remove_index(1)
            close:remove_index(1)
            cbbool = false
        end
    else
        if not cbbool then
            BuildCB()
        end
    end
end
----------------------------------------
--Video Settings
----------------------------------------
local vv = main:add(rtk.VBox{halign='right', vspacing = 10})
local vid = vv:add(rtk.HBox{valign="center", hspacing = 20})
local vt = vid:add(rtk.Text{"Video?", halign = "center", valign = "center"})
local video = vid:add(rtk.CheckBox{value = 'unchecked'})
video.onchange = function(self)
    if video.value == rtk.CheckBox.CHECKED then
        local ah = vv:add(rtk.HBox{valign="center", hspacing = 20})
        local at = ah:add(rtk.Text{"Video as additional file?", halign = "center", valign = "center"})
        add = ah:add(rtk.CheckBox{value = 'unchecked'})
    else
        vv:remove_index(2)
    end
end
----------------------------------------
--Path Selection
----------------------------------------
local pathSection = main:add(rtk.VBox{halign='center', vspacing=20})
local pathHeader = pathSection:add(rtk.Text{'Final Export?', halign = 'center', valign = 'center'})
local pathCB = pathSection:add(rtk.OptionMenu{
    menu={
        {'Draft Export', id='draft'},
        {'Pigments Export', id='pigments'},
        {'Final Render', id='final'},
    },
})
pathCB:attr('selected', 'draft')
----------------------------------------
--Complete Button
----------------------------------------
local b = main:add(rtk.Button{label='Go'})
closeCount = 0
b.onclick = function()
    if method == "nvk" then nvk()
    elseif method == "rrm" then rrm()
    elseif method == "time" then time()
    end
    if cbbool then
        if win.docked == false then
            if cb.value == rtk.CheckBox.UNCHECKED then
                if tonumber(entry.value) ~= 0 then
                    closeCount = closeCount + 1
                    if closeCount >= tonumber(entry.value) then
                        w:close()
                    end
                end
            else win:close()
            end
        else
            close:remove_index(1)
            close:remove_index(1)
        end
    end
end
win:open()
if win.docked == true then
    close:remove_index(1)
    close:remove_index(1)
    cbbool = false
end

----------------------------------------
----------------------------------------
--Main Functions
----------------------------------------
----------------------------------------
function videoDraftRenderSettings()
    if video.value == rtk.CheckBox.CHECKED then
        if add.value == rtk.CheckBox.CHECKED then
            reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT2", vidSettings, true)
            if bitDepthSettingsCB.value == rtk.CheckBox.CHECKED then reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", wavSettings32, true)
            else reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", wavSettings, true) end
        else reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", vidSettings, true)
            reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT2", "", true)
        end
    else
        if bitDepthSettingsCB.value == rtk.CheckBox.CHECKED then reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", wavSettings32, true)
        else reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", wavSettings, true) end
        reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT2", "", true)
    end
end

function nvk()
    if ambixSettingsCB.value == rtk.CheckBox.CHECKED then reaper.GetSetProjectInfo(0, "RENDER_Channels", 4, true)
    else reaper.GetSetProjectInfo(0, "RENDER_Channels", 2, true) end
    reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 64, true)
    Msg("Hi")
    if pathCB.selected == 'final' then reaper.GetSetProjectInfo_String(0, "RENDER_FILE", renderdir, true )
    elseif pathCB.selected == 'pigments' then reaper.GetSetProjectInfo_String(0, "RENDER_FILE", PigmentsRenderPath(pigmentsRenderDir), true )
    else reaper.GetSetProjectInfo_String(0, "RENDER_FILE", projdir, true ) end
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$item", true)
    videoDraftRenderSettings()
    if fullNVK.value == rtk.CheckBox.CHECKED then reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSfaa7657f9dc1372325043c3979f1f3997b109fb6"), 0)
    else 
        reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS3d1277b3748fad1eb32378430c16affef2a514b0"), 0)
        -- dofile(nvkPath..'/nvk_FOLDER_ITEMS - Render QUICK.lua')
    end
end

function rrm()
    reaper.GetSetProjectInfo(0, "RENDER_Channels", 2, true)
    reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 8, true)
    if pathCB.selected == 'final' then reaper.GetSetProjectInfo_String(0, "RENDER_FILE", renderdir, true )
    elseif pathCB.selected == 'pigments' then reaper.GetSetProjectInfo_String(0, "RENDER_FILE", PigmentsRenderPath(pigmentsRenderDir), true )
    else reaper.GetSetProjectInfo_String(0, "RENDER_FILE", projdir, true ) end
    reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", true)
    videoDraftRenderSettings()
    reaper.Main_OnCommand(41824, 0)
end

function time()
    reaper.GetSetProjectInfo(0, "RENDER_Channels", 2, true)
    reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, true)
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 2, true)
    if pathCB.selected == 'final' then reaper.GetSetProjectInfo_String(0, "RENDER_FILE", renderdir, true )
    elseif pathCB.selected == 'pigments' then reaper.GetSetProjectInfo_String(0, "RENDER_FILE", PigmentsRenderPath(pigmentsRenderDir), true )
    else reaper.GetSetProjectInfo_String(0, "RENDER_FILE", projdir, true ) end
    good, name = reaper.GetUserInputs("Filename", 1, "Filename (Wildcards valid):\nBlank = Project name extrawidth=150", "")
    if good and name ~= "" then reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", name, true)
    else reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$project", true) end
    videoDraftRenderSettings()
    reaper.Main_OnCommand(41824, 0)
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 1, true)
end