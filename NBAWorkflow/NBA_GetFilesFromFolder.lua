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

local file_path_table = {}

--_, PATH = reaper.JS_Dialog_BrowseForFolder("select a folder", "C:\\") --GET DIR FROM USER INPUT

-- TEMP HARDCODE FOR TESTING:
PATH = "P:/ZZ_NBA_TEST"

timelinePosition = 0 -- initial timeline position

trackexists = false

found_dirs, dirs_array, found_files, files_array = ultraschall.GetAllRecursiveFilesAndSubdirectories(PATH, "audio")

-- add entry to dictionary of filepath + files in file path
for k, v in pairs(dirs_array) do
    local _, files = ultraschall.GetAllFilenamesInPath(v)
    file_path_table[v] = files

    local pathnameT = split(v, "/")
    --printtable(pathnameT)
    local length = #pathnameT
    print(pathnameT[length - 1]) -- this gets the name of the folder for each stack

    for i, f in pairs(files) do
        
        -- Split name to get actor initials
        splitname = split(f, ".")
        splitname = split(splitname[1], "_")

        -- check if track already exists
        trackCount = reaper.CountTracks(0)
        
        if trackCount ~= 0 then
            for i = 0, trackCount-1 do
                print(i)
                track = reaper.GetTrack(0, i)
                _, trackname = reaper.GetTrackName(track)
                --            _, trackname = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "trackname", false)
                if trackname == splitname[#splitname] then
                    trackexists = true
                    -- reaper.SetTrackSelected(track, true)
                    -- print(trackname)
                    reaper.SetOnlyTrackSelected(track)
                    reaper.InsertMedia(f, 0)
                    break
                else
                    trackexists = false
                end
            end
        end

        if trackexists == false then
            reaper.InsertTrackAtIndex(0, false)
            track = reaper.GetTrack(0, 0)
            _, _ = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", splitname[#splitname], true)
            -- reaper.SetTrackSelected(track, true)
            reaper.SetOnlyTrackSelected(track)
            reaper.InsertMedia(f, 0)
        end

        -- check if last file in folder and set timeline position accordingly  
        if i == #file_path_table[v] then
            print(#file_path_table[v])
            timelinePosition = reaper.GetCursorPosition() + 1
        end
        
        reaper.SetEditCurPos(timelinePosition, true, true)
    end

end

-- print the table for each entry in the dictionary
for p, l in pairs(file_path_table) do
    print(p)
    for k, v in pairs(l) do
        print(v)
    end
end


-- todo:  Only have tracks for max number of files, pattern match to get track names, 
-- add to track based on file name
-- marker for file path
-- be able to render back to file path