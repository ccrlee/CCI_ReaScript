function Msg (param)
    reaper.ShowConsoleMsg(tostring (param).."\n")
end

function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      table.insert(t, str)
    end
    return t
end

function printtable (t)
    for k, v in pairs(t) do
        print (k, v)
    end
end

dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

function CreateZXRegion(tname, fname, start)
    if tname == nil then return end
    if string.lower(tname) == "zx" or string.lower(tname) == "ref" then
        -- gettakename(take)
        reaper.AddProjectMarker(0, true, start, reaper.GetCursorPosition(), fname, -1)
    end
end

-- TEMP HARDCODE FOR TESTING:
-- PATH = "P:/ZZ_NBA_TEST"


-- GET USER INPUT for repository
_, PATH = reaper.JS_Dialog_BrowseForFolder("select a folder", "C:\\") --GET DIR FROM USER INPUT

_, _ = reaper.GetSetProjectInfo_String(0, "RENDER_FILE", PATH, true)
_, _ = reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$marker/audio/$item", true)

-- INITIALIZE TIMELINE AND VARIABLES
local file_path_table = {}
local timelinePosition = 0 -- initial timeline position
reaper.SetEditCurPos(timelinePosition, true, true)
local trackexists = false

-- BEGIN SCANNING
found_dirs, dirs_array, found_files, files_array = ultraschall.GetAllRecursiveFilesAndSubdirectories(PATH, "audio")


reaper.PreventUIRefresh(1)

-- add entry to dictionary of filepath + files in file path
for k, v in pairs(dirs_array) do
    local _, files = ultraschall.GetAllFilenamesInPath(v)
    file_path_table[v] = files

    local pathnameT = split(v, "/")
    local length = #pathnameT
    -- print(pathnameT[length - 1]) -- this gets the name of the folder for each stack

    reaper.AddProjectMarker(0, false, timelinePosition, timelinePosition+1, pathnameT[length - 1], k)

    reaper.Undo_BeginBlock()

    for i, f in pairs(files) do
        
        -- strip file extension
        splitname = split(f, ".")

        -- Split name to get File name for final mix
        regname = split(splitname[1], "/")
        
        -- Split name to get actor initials
        splitname = split(splitname[1], "_")

        -- check if track already exists
        trackCount = reaper.CountTracks(0)
        
        if trackCount ~= 0 then
            for i = 0, trackCount-1 do
                track = reaper.GetTrack(0, i)
                _, trackname = reaper.GetTrackName(track)
                if trackname == splitname[#splitname] then
                    trackexists = true
                    reaper.SetOnlyTrackSelected(track)
                    reaper.InsertMedia(f, 0)

                    -- CHECK IF IS ZX OR REF
                    CreateZXRegion(trackname, regname[#regname], timelinePosition)
                    break
                else
                    trackexists = false
                end
            end
        end

        if trackexists == false then
            reaper.InsertTrackAtIndex(0, false)
            track = reaper.GetTrack(0, 0)
            _, trackname = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", splitname[#splitname], true)
            reaper.SetOnlyTrackSelected(track)
            reaper.InsertMedia(f, 0)
            -- CHECK IF IS ZX OR REF
            CreateZXRegion(trackname, regname[#regname], timelinePosition)
        end

        -- check if last file in folder and set timeline position accordingly  
        if i == #file_path_table[v] then
            timelinePosition = reaper.GetCursorPosition() + 1
        end
        
        reaper.SetEditCurPos(timelinePosition, true, true)
    end

    reaper.Undo_EndBlock("insert NBA file stack", -1)

end

reaper.AddProjectMarker2(0, true, 0, timelinePosition+1, PATH, 0, reaper.ColorToNative(0, 0, 244)|0x1000000)

reaper.PreventUIRefresh(-1)
