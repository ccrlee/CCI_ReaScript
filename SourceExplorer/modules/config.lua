-- config.lua (UPDATED WITH MODERN THEME)
local config = {
    -- Script Identification
    SCRIPT_NAME = 'SourceExplorerRL',
    SAVED_INFO_KEY = 'storedClips',

    -- Debug Mode
    DEBUG = false,

    -- UI Settings
    DEFAULT_WINDOW_WIDTH = 1200,  -- Wider for modern look
    DEFAULT_WINDOW_HEIGHT = 700,   -- Taller for better proportions
    TABLE_SPLIT_RATIO = 0.5,

    -- Modern Color Scheme (Tailwind Slate inspired - AABBGGRR format)
    COLORS = {
        -- Waveform colors (modern slate/sky theme)
        WAVEFORM_BACKGROUND = 0xFF020617,      -- slate-950 (deep dark)
        WAVEFORM_CENTER_LINE = 0xFF334155,     -- slate-700 (subtle)
        WAVEFORM_NORMAL = 0xFF5D6D7E,          -- slate-500 (base waveform)
        WAVEFORM_FADE_IN = 0xFFE60B0E,         -- sky-500 (blue fade in)
        WAVEFORM_FADE_OUT = 0xFFF8BD38,        -- sky-400 (bright fade out)
        WAVEFORM_PLAYHEAD = 0xFFF8BD38,        -- sky-400 (bright playhead)
        WAVEFORM_HOVER = 0x88F8BD38,            -- sky-400 @ 53% opacity
        WAVEFORM_PROGRESS = 0xFFF8BD38,        -- sky-400 (progress color)

        -- UI colors (modern slate palette)
        BACKGROUND_DARK = 0xFF0F1419,          -- slate-900 (main bg)
        BACKGROUND_MEDIUM = 0xFF1E2533,        -- slate-800 (panels)
        BACKGROUND_LIGHT = 0xFF293441,         -- slate-700 (elevated)
        
        TEXT_NORMAL = 0xFFDFE3E8,              -- slate-200 (primary text)
        TEXT_DISABLED = 0xFF5D6D7E,            -- slate-500 (secondary text)
        TEXT_ERROR = 0xFF2222EF,               -- red (errors)
        TEXT_SUCCESS = 0xFF00BB22,             -- green (success)
        TEXT_WARNING = 0xFF00DDFF,             -- yellow (warnings)
        
        BORDER = 0x33FFFFFF,                    -- subtle white border (20% opacity)
        SEPARATOR = 0xFF334155,                 -- slate-700
        
        ACCENT_PRIMARY = 0xFFF8BD38,           -- sky-400 (primary accent)
        ACCENT_HOVER = 0xFFE60B0E,             -- sky-500 (hover state)
        ACCENT_ACTIVE = 0xFFD78902,            -- sky-600 (active state)
        
        BUTTON_NORMAL = 0xFF334155,            -- slate-700
        BUTTON_HOVER = 0xFF3E4D5C,             -- slate-600
        BUTTON_ACTIVE = 0xFF5D6D7E,            -- slate-500
        
        TABLE_HEADER = 0xFF1E2533,             -- slate-800
        TABLE_ROW_ALT = 0x0FFFFFFF,            -- very subtle alternate (6% opacity)
        TABLE_BORDER = 0xFF334155,             -- slate-700
        TABLE_SELECTED = 0x60F8BD38,           -- sky-400 @ 38% opacity
        
        INPUT_BG = 0xFF020617,                 -- slate-950
        INPUT_BORDER = 0xFF334155,             -- slate-700
        INPUT_FOCUS = 0xFFF8BD38,              -- sky-400
    },

    -- Waveform Settings
    WAVEFORM_HEIGHT = 120,                     -- Slightly shorter, more modern
    WAVEFORM_MAX_PIXEL_WIDTH = 1200,
    WAVEFORM_VERTICAL_SCALE = 0.45,
    WAVEFORM_UCS_SCALE = 0.6,

    -- ========================================================================
    -- UCS (Universal Category System) Settings
    -- ========================================================================
    UCS = {
        -- User Defaults
        DEFAULT_CREATOR_ID = "RL",
        DEFAULT_SOURCE_ID = "MyLibrary",
        
        -- UI State
        MODE_ENABLED = false,
        EDITOR_EXPANDED = false,
        
        -- Column Visibility
        COLUMNS = {
            CATEGORY = true,
            FXNAME = true,
            KEYWORDS = true,
            CREATOR = true,
            SOURCE = true,
            USER_CATEGORY = false,
            VENDOR_CATEGORY = false,
            USER_DATA = false,
        },
        
        -- Column Widths
        COLUMN_WIDTHS = {
            CATEGORY = 120,
            FXNAME = 200,
            KEYWORDS = 150,
            CREATOR = 80,
            SOURCE = 100,
            USER_CATEGORY = 80,
            VENDOR_CATEGORY = 100,
            USER_DATA = 120,
            STATUS = 60,
        },
        
        -- Database
        DATABASE_PATH = "",
        
        -- Validation
        WARN_LONG_FXNAME = true,
        MAX_FXNAME_LENGTH = 25,
        
        -- Status Colors (matching modern theme)
        STATUS_COLORS = {
            COMPLETE   = 0x00BB22FF,        -- Green (success)
            INCOMPLETE = 0x00DDFFFF,        -- Yellow (warning)
            NOT_SET    = 0xFF2222EF,        -- Red (error)
        },
        
        -- Export
        USE_UCS_FILENAME_ON_EXPORT = false,
        
        -- UI Settings
        MAX_KEYWORD_SUGGESTIONS = 8,
        CATEGORY_DROPDOWN_HEIGHT = 400,
    },
    
    -- ========================================================================
    -- UI STYLE (Modern Design)
    -- ========================================================================
    STYLE = {
        -- Spacing
        WINDOW_PADDING = 12,
        FRAME_PADDING = 8,
        ITEM_SPACING = 8,
        BUTTON_HEIGHT = 32,
        
        -- Rounding
        WINDOW_ROUNDING = 6,
        FRAME_ROUNDING = 4,
        BUTTON_ROUNDING = 4,
        
        -- Borders
        BORDER_SIZE = 1,
        
        -- Fonts (if custom fonts are loaded)
        FONT_SIZE_NORMAL = 14,
        FONT_SIZE_SMALL = 12,
        FONT_SIZE_LARGE = 16,
    },
}

return config