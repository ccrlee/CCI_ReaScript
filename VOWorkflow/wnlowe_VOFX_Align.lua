local  DEBUG = true
local STATE = -1
local ITEMS = {}        --List of Items Key = Base 1 Index; Value = MediaItem
local ITEM_GROUPS = {}

function Msg(msg)
    if DEBUG then reaper.ShowConsoleMsg(tostring(msg) .. "\n")end
end

local RegionInfo = {}
RegionInfo.___index = RegionInfo
function RegionInfo:new()
    local instance = setmetatable({}, RegionInfo)
    instance.start = -1
    instance.guid = ""
end

function UpdateState()
    local is_new, scriptname, section, command, mode, resolution, val, context = reaper.get_action_context()

    local state = reaper.GetToggleCommandStateEx(section, command)

    if state ~= 1 then
        STATE = 1
    else
        STATE = 0
    end
end

function SetSettings()
    local ret, data = reaper.GetUserInputs(
                        "VOFX Aligner Settings", --Title
                        1, --Number of Inputs from User
                        "Time (-1 for Playhead)", -- Row Title Values (CSV)
                        "-1" -- Default Values (CSV)
                    )
    if ret then Msg(data) end
end

function GetItems()
    local num_items = reaper.CountSelectedMediaItems(0)
    local items = {}
    for i = 1, num_items do
        local item = reaper.GetSelectedMediaItem(0, i)
        items[i] = item
        -- local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        -- local ret = reaper.GetSetMediaItemInfo_String(item, "P_EXT:VOFX_POSITION", tostring(position), true)
        -- if ret == false then
        --     reaper.ReaScriptError(
        --         string.format(
        --             "!Your item %s is not writing correctly",
        --             reaper.GetSetMediaItemTakeInfo_String(
        --                 reaper.GetActiveTake(item),
        --                 "P_NAME",
        --                 "",
        --                 false
        --             )
        --         )
        --     )
        -- end


    end
    ITEMS = items

end

SetSettings()