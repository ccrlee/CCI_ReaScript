-- ContextMenu.lua
-- Reusable context menu component for Source Explorer

local ContextMenu = {}
ContextMenu.__index = ContextMenu

-- Menu item structure
local MenuItem = {}
MenuItem.__index = MenuItem

function MenuItem.new(config)
    local self = setmetatable({}, MenuItem)
    
    self.label = config.label or "Menu Item"
    self.icon = config.icon or ""
    self.callback = config.callback
    self.enabled = config.enabled ~= false  -- Default to enabled
    self.submenu = config.submenu  -- Array of MenuItems
    self.is_separator = config.is_separator or false
    
    return self
end

-- Constructor
function ContextMenu.new(id)
    local self = setmetatable({}, ContextMenu)
    
    self.id = id or "context_menu"
    self.items = {}
    self.is_open = false
    self.is_submenu_open = false

    return self
end

-- Clear all menu items
function ContextMenu:clear()
    self.items = {}
end

-- Add a regular menu item
function ContextMenu:addItem(label, callback, icon, enabled)
    local item = MenuItem.new({
        label = label,
        callback = callback,
        icon = icon or "",
        enabled = enabled
    })
    
    table.insert(self.items, item)
    return item
end

-- Add a separator
function ContextMenu:addSeparator()
    local item = MenuItem.new({
        is_separator = true
    })
    
    table.insert(self.items, item)
    return item
end

-- Add a submenu
function ContextMenu:addSubmenu(label, submenu_items, icon)
    -- Convert plain tables to MenuItem objects
    local menu_items = {}
    for i, subitem in ipairs(submenu_items) do
        if getmetatable(subitem) == MenuItem then
            -- Already a MenuItem
            menu_items[i] = subitem
        else
            -- Plain table - convert to MenuItem
            menu_items[i] = MenuItem.new({
                label = subitem.label or "Item",
                callback = subitem.callback,
                icon = subitem.icon or "",
                enabled = subitem.enabled,
                is_separator = subitem.is_separator
            })
        end
    end
    
    local item = MenuItem.new({
        label = label,
        icon = icon or "",
        submenu = menu_items
    })
    
    table.insert(self.items, item)
    return item
end

-- Open the context menu
function ContextMenu:open(ctx)
    self.is_open = true
    -- reaper.ImGui_OpenPopup(ctx, self.id)
end

-- Close the context menu
function ContextMenu:close()
    self.is_open = false
end

-- Check if menu is open
function ContextMenu:isOpen()
    return self.is_open
end

-- Draw a single menu item (recursive for submenus)
function ContextMenu:drawMenuItem(ctx, item)
    if item.is_separator then
        reaper.ImGui_Separator(ctx)
        return
    end
    
    -- FIX: Add nil check for icon
    local icon = item.icon or ""
    local display_text = icon ~= "" and (icon .. " " .. item.label) or item.label
    
    if item.submenu and #item.submenu > 0 then
        -- Draw submenu
        if reaper.ImGui_BeginMenu(ctx, display_text, item.enabled) then
            self.is_submenu_open = true
            for _, subitem in ipairs(item.submenu) do
                self:drawMenuItem(ctx, subitem)
            end
            reaper.ImGui_EndMenu(ctx)
        end
    else
        -- Draw regular menu item
        if reaper.ImGui_MenuItem(ctx, display_text, nil, false, item.enabled) then
            if item.callback then
                item.callback()
            end
            self.is_submenu_open = false
            self.is_open = false
        end
    end
end

-- Draw the context menu
function ContextMenu:draw(ctx)
    if not self.is_open then
        return false
    end

    if self.is_open and not reaper.ImGui_IsPopupOpen(ctx, self.id) then
        reaper.ImGui_OpenPopup(ctx, self.id)
    end

    if reaper.ImGui_BeginPopup(ctx, self.id) then
        -- Reset submenu flag each frame
        self.is_submenu_open = false

        for _, item in ipairs(self.items) do
            self:drawMenuItem(ctx, item)
        end

        -- Check if clicked outside
        if not reaper.ImGui_IsWindowHovered(ctx) and 
           reaper.ImGui_IsMouseClicked(ctx, reaper.ImGui_MouseButton_Left()) and not self.is_submenu_open then
            self.is_open = false
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        reaper.ImGui_EndPopup(ctx)
        return true
    else
        self.is_open = false
        return false
    end
end

return ContextMenu