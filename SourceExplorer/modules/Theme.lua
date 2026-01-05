-- Theme.lua (CORRECT VERSION FOR ReaImGui)
-- Modern dark theme for Source Explorer (Tailwind Slate inspired)
-- Uses PushStyleColor/PushStyleVar with proper Push/Pop every frame

local Theme = {}

-- Track counts for proper popping
local COLOR_COUNT = 47
local STYLEVAR_COUNT = 18

-- ==============================================================================
-- COLOR PALETTE (RRGGBBAA format)
-- ==============================================================================

Theme.Slate = {
    slate_50 = 0xF8FAFCFF,
    slate_100 = 0xF1F5F9FF,
    slate_200 = 0xE2E8F0FF,
    slate_300 = 0xCBD5E1FF,
    slate_400 = 0x94A3B8FF,
    slate_500 = 0x64748BFF,
    slate_600 = 0x475569FF,
    slate_700 = 0x334155FF,
    slate_800 = 0x1E293BFF,
    slate_900 = 0x0F172AFF,
    slate_950 = 0x020617FF
}

Theme.Sky = {
    sky_300 = 0x7DD3FCFF,
    sky_400 = 0x38BDF8FF,
    sky_500 = 0x0EA5E9FF,
    sky_600 = 0x0284C7FF
}

Theme.Accent = {
    green = 0x22C55EFF,
    yellow = 0xFBBF24FF,
    red = 0xEF4444FF,
    orange = 0xFB923CFF
}

Theme.Reaper = {
    ----------------------------------------------------------------
    -- Window / panel hierarchy
    ----------------------------------------------------------------
    bg_window = 0x121A20FF, -- main window background
    bg_child = 0x162028FF,  -- child panels
    bg_popup = 0x162028FF,  -- popups
    bg_panel = 0x162028FF,  -- menu bars, toolbars
    ----------------------------------------------------------------
    -- Frames / controls
    ----------------------------------------------------------------
    bg_frame = 0x1B2730FF,
    bg_frame_hover = 0x243544FF,
    bg_frame_active = 0x2E455AFF,
    ----------------------------------------------------------------
    -- Text
    ----------------------------------------------------------------
    text_main = 0xD7E3EAFF,
    text_dim = 0x8FA6B5FF,
    text_selected_bg = 0x3FB6C955,
    ----------------------------------------------------------------
    -- Borders & separators
    ----------------------------------------------------------------
    border_col = 0x1E2B36FF,
    border_shadow = 0x00000000,

    ----------------------------------------------------------------
    -- Headers / selectable rows (Media Explorer style)
    ----------------------------------------------------------------
    header = 0x2B8FA3FF,
    header_hover = 0x6ED3E0FF,
    header_active = 0x3FB6C9FF,
    ----------------------------------------------------------------
    -- Separators (very subtle, REAPER-style)
    ----------------------------------------------------------------
    separator = 0x1A252EFF,        -- slightly darker than bg_frame
    separator_hover = 0x1A252EFF,  -- no hover change
    separator_active = 0x1A252EFF, -- no active change
    ----------------------------------------------------------------
    -- Resize grip (window corner)
    ----------------------------------------------------------------
    resize_grip = 0x00000000,        -- invisible
    resize_grip_hover = 0x3FB6C988,  -- translucent accent
    resize_grip_active = 0x3FB6C9FF, -- solid accent
    ----------------------------------------------------------------
    -- Tabs (dock / tab bar)
    ----------------------------------------------------------------
    tab = 0x162028FF,           -- inactive tab (same as panel)
    tab_hover = 0x1B2730FF,     -- subtle lift
    tab_active = 0x1E2F3CFF,    -- active tab (slightly brighter)
    tab_unfocused = 0x121A20FF, -- background when unfocused
    tab_unfocused_active = 0x162028FF,
    ----------------------------------------------------------------
    -- Scrollbars
    ----------------------------------------------------------------
    scrollbar_bg = 0x121A20FF,
    scrollbar_grab = 0x243544FF,
    scrollbar_grab_hover = 0x2E455AFF,
    scrollbar_grab_active = 0x3FB6C9FF,
    ----------------------------------------------------------------
    -- Check / radio / slider
    ----------------------------------------------------------------
    check_mark = 0x3FB6C9FF,
    slider_grab = 0x3FB6C9FF,
    slider_grab_active = 0x6ED3E0FF,
    ----------------------------------------------------------------
    -- Tables
    ----------------------------------------------------------------
    table_header_bg = 0x162028FF,
    table_border = 0x1E2B36FF,
    table_border_strong = 0x1A252EFF,
    table_border_light = 0x162028FF,
    table_row_bg = 0x00000000, -- transparent
    table_row_alt = 0x0E1419FF,
    ----------------------------------------------------------------
    -- Plots / waveforms (REAPER-style)
    ----------------------------------------------------------------
    plot_lines = 0x8FA6B5FF,
    plot_lines_hover = 0xD7E3EAFF,
    plot_histogram = 0x3FB6C9FF,
    plot_hist_hover = 0x6ED3E0FF,
    ----------------------------------------------------------------
    -- Drag & drop / navigation
    ----------------------------------------------------------------
    drag_drop_target = 0x3FB6C9AA,
    nav_highlight = 0x3FB6C9FF,
    nav_windowing = 0x2B8FA3FF,
    modal_dim_bg = 0x00000066,

    buttons = {
        ------------------------------------------------------------
        -- Neutral (default buttons)
        ------------------------------------------------------------
        default = {
            bg     = 0x1B2730FF,
            hover  = 0x243544FF,
            active = 0x2E455AFF,
            text   = 0xD7E3EAFF,
        },

        ------------------------------------------------------------
        -- Primary action (accent, but restrained)
        ------------------------------------------------------------
        primary = {
            bg     = 0x3FB6C9FF,
            hover  = 0x6ED3E0FF,
            active = 0x2B8FA3FF,
            text   = 0xD7E3EAFF,
        },

        ------------------------------------------------------------
        -- Danger / destructive (mute, delete, clear)
        ------------------------------------------------------------
        danger = {
            bg     = 0x6A2B2BFF, -- dark muted red
            hover  = 0x8A3A3AFF,
            active = 0x4A1E1EFF,
            text   = 0xD7E3EAFF,
        },

        ------------------------------------------------------------
        -- Success / enabled (armed, active)
        ------------------------------------------------------------
        success = {
            bg     = 0x2E5A3FFF, -- muted green-blue
            hover  = 0x3E7A55FF,
            active = 0x1F3D2AFF,
            text   = 0xD7E3EAFF,
        },
    },
    ----------------------------------------------------------------
    -- Style Vars
    ----------------------------------------------------------------
    STYLE = {
        ----------------------------------------------------------------
        -- Spacing & layout
        ----------------------------------------------------------------
        window_padding = { 12, 12 },
        frame_padding = { 8, 4 },
        item_spacing = { 8, 6 },
        item_inner_spacing = { 6, 4 },
        indent_spacing = 20,
        ----------------------------------------------------------------
        -- Scroll & grab sizing
        ----------------------------------------------------------------
        scrollbar_size = 14,
        grab_min_size = 10,
        ----------------------------------------------------------------
        -- Borders (REAPER relies more on contrast than lines)
        ----------------------------------------------------------------
        window_border_size = 1,
        child_border_size = 1,
        popup_border_size = 1,
        frame_border_size = 0,
        ----------------------------------------------------------------
        -- Rounding (subtle, not “pill-shaped”)
        ----------------------------------------------------------------
        window_rounding = 6,
        child_rounding = 4,
        frame_rounding = 4,
        popup_rounding = 4,
        scrollbar_rounding = 8,
        grab_rounding = 4,
        tab_rounding = 4
    }
}

-- ==============================================================================
-- WAVEFORM COLORS
-- ==============================================================================

Theme.Waveform = {
    BACKGROUND = 0x020617FF,  -- slate_950
    CENTER_LINE = 0x334155FF, -- slate_700
    NORMAL = 0x64748BFF,      -- slate_500
    FADE_IN = 0x0EA5E9FF,     -- sky_500
    FADE_OUT = 0x38BDF8FF,    -- sky_400
    PLAYHEAD = 0x38BDF8FF,    -- sky_400
    HOVER = 0x38BDF888,       -- sky_400 @ 53%
    PROGRESS = 0x38BDF8FF     -- sky_400
}

-- ==============================================================================
-- APPLY THEME (Push)
-- Call this at the START of each frame, before ImGui_Begin
-- Must be paired with Theme.Pop() at the END of each frame
-- ==============================================================================

local currentTheme = Theme.Reaper
function Theme.Push(ctx)
    -- Push all colors (they stay pushed!)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), currentTheme.bg_window)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), currentTheme.bg_child)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), currentTheme.bg_popup)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), currentTheme.border_col)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_BorderShadow(), currentTheme.border_shadow)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), currentTheme.bg_frame)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), currentTheme.bg_frame_hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), currentTheme.bg_frame_active)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), currentTheme.text_main)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), currentTheme.text_main)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgCollapsed(), currentTheme.text_dim)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_MenuBarBg(), currentTheme.bg_panel)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarBg(), currentTheme.scrollbar_bg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrab(), currentTheme.scrollbar_grab)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabHovered(), currentTheme.scrollbar_grab_hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabActive(), currentTheme.scrollbar_grab_active)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), currentTheme.check_mark)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), currentTheme.slider_grab)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), currentTheme.slider_grab_active)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), currentTheme.buttons.default.bg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), currentTheme.buttons.default.hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), currentTheme.buttons.default.active)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), currentTheme.header)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), currentTheme.header_hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), currentTheme.header_active)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(), currentTheme.separator)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorHovered(), currentTheme.separator_hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorActive(), currentTheme.separator_active)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGrip(), currentTheme.resize_grip)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripHovered(), currentTheme.resize_grip_hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripActive(), currentTheme.resize_grip_active)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(), currentTheme.tab)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(), currentTheme.tab_hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabSelected(), currentTheme.tab_active)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabDimmed(), currentTheme.tab_unfocused)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabDimmedSelected(), currentTheme.tab_unfocused_active)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableHeaderBg(), currentTheme.table_header_bg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderStrong(), currentTheme.table_border_strong)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableBorderLight(), currentTheme.table_border_light)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBg(), currentTheme.table_row_bg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TableRowBgAlt(), currentTheme.table_row_alt)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), currentTheme.text_main)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(), currentTheme.text_dim)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextSelectedBg(), currentTheme.text_selected_bg)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DragDropTarget(), currentTheme.drag_drop_target)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavWindowingHighlight(), currentTheme.nav_highlight)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ModalWindowDimBg(), currentTheme.modal_dim_bg)

    -- Push style variables (spacing, rounding, etc.)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), currentTheme.STYLE.window_padding[1],
        currentTheme.STYLE.window_padding[2])
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), currentTheme.STYLE.frame_padding[1],
        currentTheme.STYLE.frame_padding[2])
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), currentTheme.STYLE.item_spacing[1],
        currentTheme.STYLE.item_spacing[2])
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing(), currentTheme.STYLE.item_inner_spacing[1],
        currentTheme.STYLE.item_inner_spacing[2])
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_IndentSpacing(), currentTheme.STYLE.indent_spacing)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarSize(), currentTheme.STYLE.scrollbar_size)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabMinSize(), currentTheme.STYLE.grab_min_size)

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), currentTheme.STYLE.window_border_size)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildBorderSize(), currentTheme.STYLE.child_border_size)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupBorderSize(), currentTheme.STYLE.popup_border_size)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), currentTheme.STYLE.frame_border_size)

    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), currentTheme.STYLE.window_rounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), currentTheme.STYLE.child_rounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), currentTheme.STYLE.frame_rounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(), currentTheme.STYLE.popup_rounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarRounding(), currentTheme.STYLE.scrollbar_rounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(), currentTheme.STYLE.grab_rounding)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_TabRounding(), currentTheme.STYLE.tab_rounding)
end

-- ==============================================================================
-- POP THEME
-- Call this at the END of each frame, after ImGui_End
-- Must be paired with Theme.Push() at the START of each frame
-- ==============================================================================

function Theme.Pop(ctx)
    reaper.ImGui_PopStyleColor(ctx, COLOR_COUNT)
    reaper.ImGui_PopStyleVar(ctx, STYLEVAR_COUNT)
end

-- ==============================================================================
-- LEGACY: Apply (for backwards compatibility, calls Push)
-- ==============================================================================

function Theme.Apply(ctx)
    Theme.Push(ctx)
end

function Theme.AccentButton(ctx, lable, role, width, height)
    local btn = currentTheme.buttons[role] or currentTheme.buttons.default

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), btn.bg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), btn.hover)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), btn.active)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), btn.text)

    local clicked = reaper.ImGui_Button(ctx, label, width or 0, height or 0)

    reaper.ImGui_PopStyleColor(ctx, 4)
    return clicked
end

-- ==============================================================================
-- HELPER: Get color by name
-- ==============================================================================

function Theme.GetColor(name)
    if Theme.Slate[name] then
        return Theme.Slate[name]
    end
    if Theme.Sky[name] then
        return Theme.Sky[name]
    end
    if Theme.Accent[name] then
        return Theme.Accent[name]
    end
    if Theme.Waveform[name] then
        return Theme.Waveform[name]
    end
    return 0xFFFFFFFF
end

return Theme
