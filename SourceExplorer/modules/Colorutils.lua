-- ColorUtils.lua
-- RGB-based color utilities for collections

local ColorUtils = {}

-- Convert RGB (0-255) to ImGui U32 format using ReaImGui's native function
-- @param r, g, b - RGB values 0-255
-- @param a - Alpha 0-255 (default 255)
-- @return ImGui U32 color
function ColorUtils.RGBtoU32(r, g, b, a)
    a = a or 255
    -- Convert to 0-1 range and use ImGui's function
    return reaper.ImGui_ColorConvertDouble4ToU32(r/255, g/255, b/255, a/255)
end

-- Convert RGB (0-1 range) to ImGui U32 format
-- @param r, g, b - RGB values 0.0-1.0
-- @param a - Alpha 0.0-1.0 (default 1.0)
-- @return ImGui U32 color
function ColorUtils.RGBDoubleToU32(r, g, b, a)
    a = a or 1.0
    return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a)
end

-- Extract RGB from ImGui U32 color
-- @param color - ImGui U32 color
-- @return r, g, b, a (0-255 range)
function ColorUtils.U32toRGB(color)
    local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(color)
    return math.floor(r * 255 + 0.5), 
           math.floor(g * 255 + 0.5), 
           math.floor(b * 255 + 0.5), 
           math.floor(a * 255 + 0.5)
end

-- Create semi-transparent version of color
-- @param color - ImGui U32 color
-- @param opacity - 0.0 to 1.0
-- @return ImGui U32 color with new opacity
function ColorUtils.WithOpacity(color, opacity)
    local r, g, b, _ = ColorUtils.U32toRGB(color)
    local a = math.floor(opacity * 255 + 0.5)
    return ColorUtils.RGBtoU32(r, g, b, a)
end

-- PREDEFINED COLOR PALETTE (RGB values)
ColorUtils.Palette = {
    -- Nice collection colors
    Blue    = ColorUtils.RGBtoU32(107, 142, 201),  -- Soft blue
    Green   = ColorUtils.RGBtoU32(107, 201, 158),  -- Teal green
    Red     = ColorUtils.RGBtoU32(201, 107, 107),  -- Soft red
    Orange  = ColorUtils.RGBtoU32(201, 163, 107),  -- Warm orange
    Purple  = ColorUtils.RGBtoU32(176, 107, 201),  -- Lavender
    Yellow  = ColorUtils.RGBtoU32(201, 201, 107),  -- Soft yellow
    Cyan    = ColorUtils.RGBtoU32(107, 201, 201),  -- Bright cyan
    Pink    = ColorUtils.RGBtoU32(201, 107, 176),  -- Rose pink
    Gray    = ColorUtils.RGBtoU32(170, 170, 170),  -- Medium gray
    White   = ColorUtils.RGBtoU32(255, 255, 255),  -- White
    
    -- System colors
    LightGray = ColorUtils.RGBtoU32(204, 204, 204),  -- For All Items
    Gold      = ColorUtils.RGBtoU32(255, 215, 0),    -- For Favorites
}

-- Get default color palette as array (for auto-assigning)
function ColorUtils.GetDefaultPalette()
    return {
        ColorUtils.Palette.Blue,
        ColorUtils.Palette.Green,
        ColorUtils.Palette.Red,
        ColorUtils.Palette.Orange,
        ColorUtils.Palette.Purple,
        ColorUtils.Palette.Yellow,
        ColorUtils.Palette.Cyan,
        ColorUtils.Palette.Pink,
    }
end

return ColorUtils