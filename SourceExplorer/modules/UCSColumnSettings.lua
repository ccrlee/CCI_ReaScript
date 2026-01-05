-- UCSColumnSettings.lua
-- Popup dialog for configuring which UCS columns are visible

local UCSColumnSettings = {}
UCSColumnSettings.__index = UCSColumnSettings

-- Constructor
function UCSColumnSettings.new(config)
    local self = setmetatable({}, UCSColumnSettings)
    
    self.config = config or {}
    self.show_popup = false
    
    -- Temporary settings (modified in dialog before applying)
    self.temp_settings = {
        BASIC = {
            INDEX = true,
            FILENAME = true,
            TAKENAME = true,
            FAVORITE = true,
            STATUS = true,  -- Always visible
        },
        UCS = {
            CATEGORY = true,
            FXNAME = true,
            KEYWORDS = true,
            CREATOR = true,
            SOURCE = true,
            USER_CATEGORY = false,
            VENDOR_CATEGORY = false,
            USER_DATA = false,
        }
    }
    
    return self
end

-- Open the popup
function UCSColumnSettings:open()
    self.show_popup = true
    -- Copy current config to temp settings
    self:loadFromConfig()
end

-- Close the popup
function UCSColumnSettings:close()
    self.show_popup = false
end

-- Load current settings from config
function UCSColumnSettings:loadFromConfig()
    if not self.config.UCS or not self.config.UCS.COLUMNS then
        return
    end
    
    -- Copy UCS column settings
    for key, value in pairs(self.config.UCS.COLUMNS) do
        if self.temp_settings.UCS[key] ~= nil then
            self.temp_settings.UCS[key] = value
        end
    end
end

-- Apply preset configuration
function UCSColumnSettings:applyPreset(preset)
    if preset == "essential" then
        -- UCS Essential: Category, FX Name, Status
        self.temp_settings.UCS.CATEGORY = true
        self.temp_settings.UCS.FXNAME = true
        self.temp_settings.UCS.KEYWORDS = false
        self.temp_settings.UCS.CREATOR = false
        self.temp_settings.UCS.SOURCE = false
        self.temp_settings.UCS.USER_CATEGORY = false
        self.temp_settings.UCS.VENDOR_CATEGORY = false
        self.temp_settings.UCS.USER_DATA = false
        
    elseif preset == "standard" then
        -- UCS Standard: Essential + Creator + Source
        self.temp_settings.UCS.CATEGORY = true
        self.temp_settings.UCS.FXNAME = true
        self.temp_settings.UCS.KEYWORDS = true
        self.temp_settings.UCS.CREATOR = true
        self.temp_settings.UCS.SOURCE = true
        self.temp_settings.UCS.USER_CATEGORY = false
        self.temp_settings.UCS.VENDOR_CATEGORY = false
        self.temp_settings.UCS.USER_DATA = false
        
    elseif preset == "complete" then
        -- UCS Complete: All fields
        self.temp_settings.UCS.CATEGORY = true
        self.temp_settings.UCS.FXNAME = true
        self.temp_settings.UCS.KEYWORDS = true
        self.temp_settings.UCS.CREATOR = true
        self.temp_settings.UCS.SOURCE = true
        self.temp_settings.UCS.USER_CATEGORY = true
        self.temp_settings.UCS.VENDOR_CATEGORY = true
        self.temp_settings.UCS.USER_DATA = true
    end
end

-- Reset to defaults
function UCSColumnSettings:resetToDefaults()
    self.temp_settings.UCS.CATEGORY = true
    self.temp_settings.UCS.FXNAME = true
    self.temp_settings.UCS.KEYWORDS = true
    self.temp_settings.UCS.CREATOR = true
    self.temp_settings.UCS.SOURCE = true
    self.temp_settings.UCS.USER_CATEGORY = false
    self.temp_settings.UCS.VENDOR_CATEGORY = false
    self.temp_settings.UCS.USER_DATA = false
end

-- Apply settings to config
function UCSColumnSettings:apply()
    if not self.config.UCS then
        self.config.UCS = {}
    end
    if not self.config.UCS.COLUMNS then
        self.config.UCS.COLUMNS = {}
    end
    
    -- Apply UCS column settings
    for key, value in pairs(self.temp_settings.UCS) do
        self.config.UCS.COLUMNS[key] = value
    end
    
    return true  -- Settings applied
end

-- Draw the popup
function UCSColumnSettings:draw(ctx)
    if not self.show_popup then
        return false
    end
    
    -- Open popup
    reaper.ImGui_OpenPopup(ctx, "Column Visibility")
    
    -- Set popup size
    reaper.ImGui_SetNextWindowSize(ctx, 400, 500, reaper.ImGui_Cond_Appearing())
    
    local applied = false
    
    if reaper.ImGui_BeginPopupModal(ctx, "Column Visibility", true, reaper.ImGui_WindowFlags_NoResize()) then
        
        reaper.ImGui_Text(ctx, "COLUMN VISIBILITY")
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- BASIC COLUMNS SECTION
        -- ====================================================================
        reaper.ImGui_Text(ctx, "Basic Columns:")
        reaper.ImGui_Spacing(ctx)
        
        -- Index (always on, disabled checkbox)
        reaper.ImGui_BeginDisabled(ctx)
        reaper.ImGui_Checkbox(ctx, "Index", true)
        reaper.ImGui_EndDisabled(ctx)
        
        -- Filename (always on, disabled checkbox)
        reaper.ImGui_BeginDisabled(ctx)
        reaper.ImGui_Checkbox(ctx, "Filename", true)
        reaper.ImGui_EndDisabled(ctx)
        
        -- Take Name (always on, disabled checkbox)
        reaper.ImGui_BeginDisabled(ctx)
        reaper.ImGui_Checkbox(ctx, "Take Name", true)
        reaper.ImGui_EndDisabled(ctx)
        
        -- Favorite (always on, disabled checkbox)
        reaper.ImGui_BeginDisabled(ctx)
        reaper.ImGui_Checkbox(ctx, "Favorite (⭐)", true)
        reaper.ImGui_EndDisabled(ctx)
        
        -- UCS Status (always on, disabled checkbox)
        reaper.ImGui_BeginDisabled(ctx)
        reaper.ImGui_Checkbox(ctx, "UCS Status (always visible)", true)
        reaper.ImGui_EndDisabled(ctx)
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- UCS COLUMNS SECTION
        -- ====================================================================
        reaper.ImGui_Text(ctx, "UCS Columns (only in UCS Mode):")
        reaper.ImGui_Spacing(ctx)
        
        -- Category
        local changed, new_val = reaper.ImGui_Checkbox(ctx, "Category (dropdown)", self.temp_settings.UCS.CATEGORY)
        if changed then
            self.temp_settings.UCS.CATEGORY = new_val
        end
        
        -- FX Name
        changed, new_val = reaper.ImGui_Checkbox(ctx, "FX Name (text)", self.temp_settings.UCS.FXNAME)
        if changed then
            self.temp_settings.UCS.FXNAME = new_val
        end
        
        -- Keywords
        changed, new_val = reaper.ImGui_Checkbox(ctx, "Keywords (display)", self.temp_settings.UCS.KEYWORDS)
        if changed then
            self.temp_settings.UCS.KEYWORDS = new_val
        end
        
        -- Creator ID
        changed, new_val = reaper.ImGui_Checkbox(ctx, "Creator ID (text)", self.temp_settings.UCS.CREATOR)
        if changed then
            self.temp_settings.UCS.CREATOR = new_val
        end
        
        -- Source ID
        changed, new_val = reaper.ImGui_Checkbox(ctx, "Source ID (text)", self.temp_settings.UCS.SOURCE)
        if changed then
            self.temp_settings.UCS.SOURCE = new_val
        end
        
        -- User Category
        changed, new_val = reaper.ImGui_Checkbox(ctx, "User Category (text)", self.temp_settings.UCS.USER_CATEGORY)
        if changed then
            self.temp_settings.UCS.USER_CATEGORY = new_val
        end
        
        -- Vendor Category
        changed, new_val = reaper.ImGui_Checkbox(ctx, "Vendor Category (text)", self.temp_settings.UCS.VENDOR_CATEGORY)
        if changed then
            self.temp_settings.UCS.VENDOR_CATEGORY = new_val
        end
        
        -- User Data
        changed, new_val = reaper.ImGui_Checkbox(ctx, "User Data (text)", self.temp_settings.UCS.USER_DATA)
        if changed then
            self.temp_settings.UCS.USER_DATA = new_val
        end
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- QUICK PRESETS SECTION
        -- ====================================================================
        reaper.ImGui_Text(ctx, "Quick Presets:")
        reaper.ImGui_Spacing(ctx)
        
        if reaper.ImGui_Button(ctx, "• UCS Essential", 350, 0) then
            self:applyPreset("essential")
        end
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx, "Category, FX Name, Status only")
        end
        
        if reaper.ImGui_Button(ctx, "• UCS Standard", 350, 0) then
            self:applyPreset("standard")
        end
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx, "Essential + Keywords, Creator, Source")
        end
        
        if reaper.ImGui_Button(ctx, "• UCS Complete", 350, 0) then
            self:applyPreset("complete")
        end
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx, "All UCS fields visible")
        end
        
        reaper.ImGui_Spacing(ctx)
        reaper.ImGui_Separator(ctx)
        reaper.ImGui_Spacing(ctx)
        
        -- ====================================================================
        -- ACTION BUTTONS
        -- ====================================================================
        
        -- Apply button
        if reaper.ImGui_Button(ctx, "Apply", 120, 0) then
            self:apply()
            self:close()
            applied = true
        end
        
        reaper.ImGui_SameLine(ctx)
        
        -- Cancel button
        if reaper.ImGui_Button(ctx, "Cancel", 120, 0) then
            self:close()
        end
        
        reaper.ImGui_SameLine(ctx)
        
        -- Reset button
        if reaper.ImGui_Button(ctx, "Reset", 120, 0) then
            self:resetToDefaults()
        end
        if reaper.ImGui_IsItemHovered(ctx) then
            reaper.ImGui_SetTooltip(ctx, "Reset to default settings")
        end
        
        reaper.ImGui_EndPopup(ctx)
    else
        self:close()
    end
    
    return applied
end

return UCSColumnSettings