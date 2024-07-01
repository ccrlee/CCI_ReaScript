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

--_, PATH = reaper.JS_Dialog_BrowseForFolder("select a folder", "C:\\")

-- TEMP HARDCODE FOR TESTING:
PATH = "P:/ZZ_NBA_TEST"

timelinePosition = 0 -- initial timeline position

found_dirs, dirs_array, found_files, files_array = ultraschall.GetAllRecursiveFilesAndSubdirectories(PATH, "audio")

--Msg(found_dirs)



-- add entry to dictionary of filepath + files in file path
for k, v in pairs(dirs_array) do
    local _, files = ultraschall.GetAllFilenamesInPath(v)
    file_path_table[v] = files

    local pathnameT = split(v, "/")
    --printtable(pathnameT)
    local length = #pathnameT
    print(pathnameT[length - 1])

    for i, f in pairs(files) do
        -- local fileext = f:match('.-%.(.*)')
        -- if reaper.IsMediaExtension(f, false) then
            reaper.InsertMedia(f, 1)
        -- end
    end

end

-- print the table for each entry in the dictionary
for p, l in pairs(file_path_table) do
    print(p)
    for k, v in pairs(l) do
        print(v)
    end
end