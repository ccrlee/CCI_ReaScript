-- Storage.lua
-- Serialization and persistence functions for Source Explorer

local Storage = {}

function Storage.TableToString(tbl)
    local function serialize(val, depth)
        depth = depth or 0
        local indent = string.rep("  ", depth)
        local t = type(val)

        if t == 'table' then
            local result = "{\n"
            for k, v in pairs(val) do
                result = result .. indent .. "  "

                -- Handle key
                if type(k) == 'number' then
                    result = result .. '[' .. k .. '] = '
                else
                    result = result .. '[' .. string.format("%q", k) .. '] = '
                end

                -- Handle value
                result = result .. serialize(v, depth + 1) .. ',\n'
            end

            result = result .. indent .. '}'
            return result
        elseif t == 'string' then
            return string.format("%q", val)
        elseif t == 'number' or t == 'boolean' then
            return tostring(val)
        else
            return 'nil'
        end
    end

    return serialize(tbl)
end

function Storage.StringToTable(str)
   if not str or str == "" then return nil end
   
   local func, err = load("return " .. str)
   if not func then
        reaper.ShowConsoleMsg("Error loading: " .. tostring(err) .. "\n")
        return nil
   end

   local success, result = pcall(func)
   if not success then
        reaper.ShowConsoleMsg("Error executing: " .. tostring(result) .. "\n")
        return nil
   end

   return result
end

-- Save table to project extended state
function Storage.SaveTableToProject(script_name, key, table_data)
    local tbl_string = Storage.TableToString(table_data)
    reaper.SetProjExtState(0, script_name, key, tbl_string)
    return tbl_string
end

-- Load table from project extended state
function Storage.LoadTableFromProject(script_name, key)
    local retval, tbl_string = reaper.GetProjExtState(0, script_name, key)
    if retval > 0 and tbl_string ~= "" then
        return Storage.StringToTable(tbl_string)
    end
    return nil
end

-- Export data to a Lua file
function Storage.ExportToFile(filepath, data)
    local outputStr = Storage.TableToString(data)
    
    local file = io.open(filepath, 'w')
    if not file then 
        return false, "Could not open file for writing"
    end
    
    file:write(outputStr)
    file:close()
    
    return true, "File exported successfully"
end

-- Import data from a Lua file
function Storage.ImportFromFile(filepath)
    local file = io.open(filepath, 'r')
    if not file then
        return nil, "Could not open file for reading"
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        return nil, "File is empty"
    end
    
    local imported_data = Storage.StringToTable(content)
    if not imported_data then
        return nil, "Failed to parse file content"
    end
    
    return imported_data
end

-- Import data with file browser dialog
function Storage.ImportDataWithDialog(targetTbl, converter)
    local num, file = reaper.JS_Dialog_BrowseForOpenFiles('Open Data', reaper.GetProjectPath(), '', "Lua script files\0*.lua\0", false)
    
    if not file or file == "" then 
        return false, "No file selected"
    end

    local imported_data, err = Storage.ImportFromFile(file)
    if not imported_data then
        return false, err
    end
    
-- Convert each item if converter provided
    for k, v in pairs(imported_data) do
        if converter then
            table.insert(targetTbl, converter(v))
        else
            table.insert(targetTbl, v)
        end
    end
    
    return true, "Imported " .. #imported_data .. " items"
end

-- Export data with auto-generated filename in project directory
function Storage.ExportToProjectDirectory(data, filename)
    local projectPath = reaper.GetProjectPath()
    
    if projectPath == "" then 
        return false, "Project is not saved!"
    end
    
    filename = filename or 'CapturedSource.lua'
    local fullPath = projectPath .. '/' .. filename
    
    return Storage.ExportToFile(fullPath, data)
end

return Storage