-- @description Sets clip gain on selected item to specified LUFS level in metadata file with offset
-- @author William N. Lowe
-- @version 0.9

local INDEX = 2

local function setLUFS(item)
    local projectPath = reaper.GetProjectPath("")
    local dir = nil
    if projectPath ~= "" then dir = projectPath
    else reaper.ShowMessageBox("Project is not saved!", "Script Error", 0) return false end
    local filePath = dir.."/LoudnessSettings.lua"
    local r = reaper.file_exists(filePath)
    if not r then reaper.ShowMessageBox("Loudness Settings file not found!", "Script Error", 0) return false end

    local metadata, d = dofile(filePath)

    
    local take = reaper.GetActiveTake(item)
    local startTime = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local endTime = startTime + length
    local source = reaper.GetMediaItemTake_Source(take)
    local target = 0
    local offset = metadata["Offsets"][INDEX]
    local normalize = 0
    if length < metadata["CutoffTime"] then
        target = metadata["TargetsM"][INDEX]
        normalize = reaper.CalculateNormalization(source, 4, target + offset, startTime, endTime)
    else
        target = metadata["TargetsI"][INDEX]
        normalize = reaper.CalculateNormalization(source, 0, target + offset, startTime, endTime)
    end

    reaper.SetMediaItemInfo_Value(item, "D_VOL", normalize)
end

local numItems = reaper.CountSelectedMediaItems(0)
if numItems > 1 then
   for i = 0, numItems do
    local item = reaper.GetSelectedMediaItem(0, i)
    setLUFS(item)
   end
elseif numItems == 1 then setLUFS(reaper.GetSelectedMediaItem(0, 0))
else
    return
end

reaper.ThemeLayout_RefreshAll()
