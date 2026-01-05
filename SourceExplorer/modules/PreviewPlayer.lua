-- PreviewPlayer.lua
-- Audio preview and playback system for Source Explorer

local PreviewPlayer = {}
PreviewPlayer.__index = PreviewPlayer

-- Constructor
function PreviewPlayer.new()
    local self = setmetatable({}, PreviewPlayer)
    
    self.playing = false
    self.preview = nil
    self.start_time = 0
    self.end_time = 0
    self.item_props = nil
    self.filepath = nil
    
    return self
end

-- Play preview with item properties
-- click_offset: optional position to start from (for click-to-play)
function PreviewPlayer:play(filepath, item_props, click_offset)
    if not filepath or not item_props then
        return false
    end
    
    -- Stop any existing preview first
    self:stop()
    
    -- Create source and preview
    local source = reaper.PCM_Source_CreateFromFile(filepath)
    if not source then
        return false
    end
    
    self.preview = reaper.CF_CreatePreview(source)
    if not self.preview then
        return false
    end
    
    -- Calculate start and end positions
    local start_pos = click_offset or item_props.source_offset
    local end_pos = item_props.source_offset + item_props.item_length
    
    -- Set time range
    reaper.CF_Preview_SetValue(self.preview, "D_POSITION", start_pos)
    reaper.CF_Preview_SetValue(self.preview, "D_LENGTH", end_pos - start_pos)
    
    -- Set playback rate
    reaper.CF_Preview_SetValue(self.preview, "D_PLAYRATE", item_props.playback_rate)
    
    -- Set preserve pitch
    reaper.CF_Preview_SetValue(self.preview, "B_PPITCH", item_props.preserve_pitch and 1 or 0)
    
    -- Set volume
    reaper.CF_Preview_SetValue(self.preview, "D_VOLUME", item_props.volume)
    
    -- Set fade in/out
    reaper.CF_Preview_SetValue(self.preview, "D_FADEINLEN", item_props.fade_in)
    reaper.CF_Preview_SetValue(self.preview, "D_FADEOUTLEN", item_props.fade_out)
    
    -- Start playback
    reaper.CF_Preview_Play(self.preview)
    
    -- Store state
    self.playing = true
    self.start_time = start_pos
    self.end_time = end_pos
    self.item_props = item_props
    self.filepath = filepath
    
    return true
end

-- Stop preview playback
function PreviewPlayer:stop()
    if self.preview then
        reaper.CF_Preview_Stop(self.preview)
        self.preview = nil
    end
    self.playing = false
    self.item_props = nil
    self.filepath = nil
end

-- Check if currently playing
function PreviewPlayer:isPlaying()
    return self.playing
end

-- Get current playback position
-- Returns: position (number or nil if not playing)
function PreviewPlayer:getPosition()
    if not self.preview then
        return nil
    end
    
    local retval, pos = reaper.CF_Preview_GetValue(self.preview, "D_POSITION")
    if retval then
        return pos
    end
    
    return nil
end

-- Get playback progress (0.0 to 1.0)
-- Returns: progress (number or nil if not playing)
function PreviewPlayer:getProgress()
    if not self.playing or not self.item_props then
        return nil
    end
    
    local pos = self:getPosition()
    if not pos then
        return nil
    end
    
    local duration = self.end_time - self.start_time
    if duration <= 0 then
        return 0
    end
    
    local progress = (pos - self.start_time) / duration
    return math.max(0, math.min(1, progress))  -- Clamp to 0-1
end

-- Check if preview has finished playing
function PreviewPlayer:hasFinished()
    if not self.playing then
        return false
    end
    
    local pos = self:getPosition()
    if not pos then
        return true  -- Can't get position, assume finished
    end
    
    return pos >= self.end_time
end

-- Update - call this in main loop to handle auto-stop
-- Returns: true if preview auto-stopped
function PreviewPlayer:update()
    if self.playing and self:hasFinished() then
        self:stop()
        return true
    end
    return false
end

-- Toggle play/pause
-- Returns: true if now playing, false if stopped
function PreviewPlayer:toggle(filepath, item_props, click_offset)
    if self.playing then
        self:stop()
        return false
    else
        self:play(filepath, item_props, click_offset)
        return true
    end
end

-- Set volume (0.0 to 1.0+)
function PreviewPlayer:setVolume(volume)
    if self.preview then
        reaper.CF_Preview_SetValue(self.preview, "D_VOLUME", volume)
        if self.item_props then
            self.item_props.volume = volume
        end
    end
end

-- Get current volume
function PreviewPlayer:getVolume()
    if self.preview then
        local retval, vol = reaper.CF_Preview_GetValue(self.preview, "D_VOLUME")
        if retval then
            return vol
        end
    end
    return 1.0
end

-- Seek to position (in seconds from start)
function PreviewPlayer:seekTo(position)
    if not self.preview then
        return false
    end
    
    local seek_pos = self.start_time + position
    seek_pos = math.max(self.start_time, math.min(self.end_time, seek_pos))
    
    reaper.CF_Preview_SetValue(self.preview, "D_POSITION", seek_pos)
    return true
end

-- Seek to normalized position (0.0 to 1.0)
function PreviewPlayer:seekToNormalized(normalized_pos)
    if not self.playing or not self.item_props then
        return false
    end
    
    local duration = self.end_time - self.start_time
    local position = normalized_pos * duration
    
    return self:seekTo(position)
end

-- Get info string for display
function PreviewPlayer:getInfoString()
    if not self.playing then
        return "Stopped"
    end
    
    local pos = self:getPosition()
    if not pos then
        return "Playing..."
    end
    
    local current = pos - self.start_time
    local duration = self.end_time - self.start_time
    
    return string.format("%.2fs / %.2fs", current, duration)
end

return PreviewPlayer