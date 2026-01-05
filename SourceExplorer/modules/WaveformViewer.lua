-- WaveformViewer.lua (ENHANCED WITH SPECTRAL COLORS)
-- Waveform display component for Source Explorer with spectral view color matching

local WaveformViewer = {}
WaveformViewer.__index = WaveformViewer

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"
local Utils = require("Utils")
local config = require("config")

-- ==============================================================================
-- SPECTRAL COLOR SYSTEM (from REAPER's spectral view)
-- ==============================================================================

-- Read REAPER's spectral peak hue offset from preferences
local function GetSpectralHueOffset()
    local _, h_offset_str = reaper.get_config_var_string("specpeak_huel")
    if h_offset_str and h_offset_str ~= "" then
        local h_val = tonumber(h_offset_str)
        if h_val then
            -- Map from 0-1 to 0-360 degrees with offset
            return ((h_val % 1) + 0.06) * 360
        end
    end
    return 21.6  -- Default offset (0.06 * 360)
end

-- HSL to RGB conversion
local function hue2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1/6 then return p + (q - p) * 6 * t end
    if t < 1/2 then return q end
    if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
    return p
end

local function hslToRgb(h, s, l)
    local r, g, b

    if s == 0 then
        r, g, b = l, l, l
    else
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q

        r = hue2rgb(p, q, h + 1/3)
        g = hue2rgb(p, q, h)
        b = hue2rgb(p, q, h - 1/3)
    end
    
    return r, g, b
end

-- Map frequency to hue value (logarithmic mapping)
local function mapFrequencyToHue(freq)
    return 52.1153 * math.log(0.05 * freq)
end

-- Get color for a given frequency (matching REAPER's spectral colors)
local function GetColorFromFreq(freq, alpha, h_offset)
    if not freq or freq <= 0 then
        return config.COLORS.WAVEFORM_NORMAL  -- Fallback to normal color
    end
    
    local h = (mapFrequencyToHue(freq) + h_offset) / 360
    local s = 1.0  -- Full saturation
    local l = 0.5  -- 50% lightness
    
    local r, g, b = hslToRgb(h, s, l)
    
    -- Apply alpha
    alpha = alpha or 1.0
    
    -- Convert to ImGui AABBGGRR format
    return reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, alpha)
end

-- Linear interpolation
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- ==============================================================================
-- CONSTRUCTOR
-- ==============================================================================

function WaveformViewer.new(options)
    options = options or {}
    
    local self = setmetatable({}, WaveformViewer)
    
    self.cache = {}
    self.height = options.height or config.WAVEFORM_HEIGHT
    self.max_pixel_width = options.max_pixel_width or config.WAVEFORM_MAX_PIXEL_WIDTH
    
    -- Spectral mode settings
    self.spectral_mode = options.spectral_mode or false
    self.spectral_hue_offset = GetSpectralHueOffset()
    
    return self
end

-- ==============================================================================
-- CACHE KEY GENERATION
-- ==============================================================================

function WaveformViewer:getCacheKey(filepath, pixel_count, start_time, end_time, item_props, spectral)
    local key = filepath .. "_" .. tostring(start_time) .. "_" .. tostring(end_time) .. "_" .. tostring(pixel_count)
    
    if item_props then
        key = key .. "_" .. tostring(item_props.fade_in) 
        key = key .. "_" .. tostring(item_props.fade_out) 
        key = key .. "_" .. tostring(item_props.playback_rate)
    end
    
    if spectral then
        key = key .. "_spectral"
    end
    
    return key
end

-- ==============================================================================
-- PEAK EXTRACTION WITH OPTIONAL SPECTRAL DATA
-- ==============================================================================

function WaveformViewer:getPeaksFromFile(filepath, pixel_count, start_time, end_time, item_props, extract_spectral)
    -- Check cache first
    local cache_key = self:getCacheKey(filepath, pixel_count, start_time, end_time, item_props, extract_spectral)
    
    if self.cache[cache_key] then
        return self.cache[cache_key]
    end
    
    reaper.PreventUIRefresh(1)
    
    local source = reaper.PCM_Source_CreateFromFile(filepath)
    if not source then
        reaper.PreventUIRefresh(-1)
        return nil
    end
    
    local src_len = reaper.GetMediaSourceLength(source)
    local srate = reaper.GetMediaSourceSampleRate(source)
    local channels = reaper.GetMediaSourceNumChannels(source)
    
    if not srate or srate == 0 then srate = 44100 end
    
    -- If no time range specified, use full source
    start_time = start_time or 0
    end_time = end_time or src_len
    
    -- Clamp to source bounds
    start_time = math.max(0, math.min(start_time, src_len))
    end_time = math.max(start_time, math.min(end_time, src_len))
    
    local window_len = end_time - start_time
    
    -- Create temporary track and item
    local track_idx = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(track_idx, true)
    local track = reaper.GetTrack(0, track_idx)
    local item = reaper.AddMediaItemToTrack(track)
    reaper.SetMediaItemLength(item, src_len, false)
    local take = reaper.AddTakeToMediaItem(item)
    reaper.SetMediaItemTake_Source(take, source)
    reaper.UpdateItemInProject(item)
    
    -- Decide whether to use spectral extraction
    local use_spectral = extract_spectral and self.spectral_mode
    local peaks_data
    
    if use_spectral then
        -- Extract with spectral data using GetMediaItemTake_Peaks
        peaks_data = self:extractSpectralPeaks(take, pixel_count, start_time, window_len, channels, srate)
    else
        -- Use original audio accessor method
        peaks_data = self:extractRegularPeaks(take, pixel_count, start_time, window_len, channels, srate)
    end
    
    -- Cleanup
    reaper.DeleteTrackMediaItem(track, item)
    reaper.DeleteTrack(track)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    
    if not peaks_data then
        return nil
    end
    
    -- Build result with metadata
    local result = {
        peaks = peaks_data.peaks,
        freq_data = peaks_data.freq_data,  -- nil if not spectral
        length = window_len,
        start_time = start_time,
        end_time = end_time,
        pixel_count = pixel_count,
        fade_in = item_props and item_props.fade_in or 0,
        fade_out = item_props and item_props.fade_out or 0,
        is_spectral = use_spectral
    }
    
    -- Cache the result
    self.cache[cache_key] = result
    
    return result
end

-- ==============================================================================
-- REGULAR PEAK EXTRACTION (Original Method)
-- ==============================================================================

function WaveformViewer:extractRegularPeaks(take, pixel_count, start_time, window_len, channels, srate)
    local accessor = reaper.CreateTakeAudioAccessor(take)
    if not accessor then
        return nil
    end
    
    local peaks = {}
    local samples_per_pixel = math.max(1, math.floor((srate * window_len) / pixel_count))
    local temp = reaper.new_array(samples_per_pixel * channels)
    
    for i = 0, pixel_count - 1 do
        local pos = start_time + (i * samples_per_pixel / srate)
        
        temp.clear()
        reaper.GetAudioAccessorSamples(accessor, srate, channels, pos, samples_per_pixel, temp)
        
        local min_val = math.huge
        local max_val = -math.huge
        
        for j = 1, #temp, channels do
            local sample = temp[j]
            if sample then
                if sample < min_val then min_val = sample end
                if sample > max_val then max_val = sample end
            end
        end
        
        if min_val == math.huge or max_val == -math.huge then
            min_val, max_val = 0, 0
        end
        
        peaks[i + 1] = {min_val, max_val}
    end
    
    reaper.DestroyAudioAccessor(accessor)
    
    return {peaks = peaks, freq_data = nil}
end

-- ==============================================================================
-- SPECTRAL PEAK EXTRACTION (New Method)
-- ==============================================================================

function WaveformViewer:extractSpectralPeaks(take, pixel_count, start_time, window_len, channels, srate)
    local peakrate = pixel_count / window_len
    local n_spls = math.floor(window_len * peakrate + 0.5)
    
    -- Request spectral data (want_extra_type = 115 = 's' for spectral)
    local want_extra_type = 115
    local buf = reaper.new_array(n_spls * channels * 3)
    buf.clear()
    
    local retval = reaper.GetMediaItemTake_Peaks(take, peakrate, start_time, channels, n_spls, want_extra_type, buf)
    local spl_cnt = (retval & 0xfffff)
    local ext_type = (retval & 0x1000000) >> 24
    
    if spl_cnt == 0 or ext_type == 0 then
        -- Spectral extraction failed, fall back to regular
        return self:extractRegularPeaks(take, pixel_count, start_time, window_len, channels, srate)
    end
    
    -- Parse spectral peak data
    local peaks = {}
    local freq_data = {}
    
    for i = 1, n_spls do
        local idx = (i - 1) * channels + 1
        
        -- Get min/max peaks (average across channels if stereo)
        local min_val = buf[idx + n_spls * channels]
        local max_val = buf[idx]
        
        if channels > 1 then
            -- Average channels
            min_val = (min_val + buf[idx + 1 + n_spls * channels]) / 2
            max_val = (max_val + buf[idx + 1]) / 2
        end
        
        -- Get spectral frequency data
        local spectral_idx
        if channels > 1 then
            spectral_idx = idx + n_spls * (channels + 2)
        else
            spectral_idx = idx + n_spls * (channels + 1)
        end
        
        local freq = buf[spectral_idx] and (buf[spectral_idx] & 0x7fff) or 0
        
        peaks[i] = {min_val, max_val}
        freq_data[i] = freq
    end
    
    return {peaks = peaks, freq_data = freq_data}
end

-- ==============================================================================
-- GET PEAKS FROM AUDIO ITEM
-- ==============================================================================

function WaveformViewer:getPeaksFromAudioItem(audio_item, pixel_count)
    local item_props = audio_item:getProperties()
    
    if not item_props or not item_props.item_length or item_props.item_length <= 0 then
        return self:getPeaksFromFile(audio_item.file, pixel_count, nil, nil, nil, self.spectral_mode)
    end
    
    local end_time = item_props.source_offset + item_props.item_length
    
    return self:getPeaksFromFile(audio_item.file, pixel_count, item_props.source_offset, end_time, item_props, self.spectral_mode)
end

-- ==============================================================================
-- DRAWING
-- ==============================================================================

function WaveformViewer:draw(ctx, audio_item, player, height)
    height = height or self.height
    
    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    
    if not reaper.ImGui_BeginChild(ctx, 'WaveformSection', avail_w, height, reaper.ImGui_ChildFlags_Border()) then
        return
    end
    
    if not audio_item then
        reaper.ImGui_TextColored(ctx, config.COLORS.TEXT_DISABLED, "No item selected")
        reaper.ImGui_EndChild(ctx)
        return
    end
    
    local filename = audio_item:getFileName()
    local item_props = audio_item:getProperties()
    
    if not item_props then
        reaper.ImGui_TextColored(ctx, config.COLORS.TEXT_ERROR, "Could not parse item properties")
        reaper.ImGui_EndChild(ctx)
        return
    end
    
    local source_offset = item_props.source_offset
    local item_length = item_props.item_length
    
    -- Build info string
    local time_info = string.format(" [%.2fs - %.2fs]", source_offset, source_offset + item_length)
    if item_props.playback_rate ~= 1.0 then
        time_info = time_info .. string.format(" %.2fx", item_props.playback_rate)
    end
    if item_props.fade_in > 0 or item_props.fade_out > 0 then
        time_info = time_info .. string.format(" (FI:%.2fs FO:%.2fs)", item_props.fade_in, item_props.fade_out)
    end
    
    -- Header with spectral mode toggle
    reaper.ImGui_Text(ctx, "Waveform: " .. filename .. time_info)
    reaper.ImGui_SameLine(ctx)
    
    -- Spectral mode toggle button
    if reaper.ImGui_SmallButton(ctx, self.spectral_mode and "🌈 Spectral" or "🎵 Normal") then
        self.spectral_mode = not self.spectral_mode
        -- Update hue offset when toggling
        if self.spectral_mode then
            self.spectral_hue_offset = GetSpectralHueOffset()
        end
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetTooltip(ctx, "Toggle spectral color view (matches REAPER's spectral peaks)")
    end
    
    reaper.ImGui_SameLine(ctx)
    
    -- Playback controls
    if player and player:isPlaying() then
        if reaper.ImGui_Button(ctx, "Stop") then
            player:stop()
        end
    else
        if reaper.ImGui_Button(ctx, "Play") then
            if player then
                player:play(audio_item.file, item_props)
            end
        end
    end

    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space()) then
        player:toggle(audio_item.file, item_props)
    end
    
    local w, h = reaper.ImGui_GetContentRegionAvail(ctx)
    
    -- Reserve space for waveform
    reaper.ImGui_InvisibleButton(ctx, "##waveform", w, h)
    
    -- Get mouse interaction
    local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
    local item_x, item_y = reaper.ImGui_GetItemRectMin(ctx)
    local item_x_max, item_y_max = reaper.ImGui_GetItemRectMax(ctx)
    
    local mouse_relative_x = mouse_x - item_x
    local normalized_pos = math.max(0, math.min(1, mouse_relative_x / w))
    
    -- Mouse playback interaction
    if player and reaper.ImGui_IsItemActive(ctx) and reaper.ImGui_IsMouseDown(ctx, reaper.ImGui_MouseButton_Left()) then
        if not player:isPlaying() then
            local click_offset = source_offset + (normalized_pos * item_length)
            player:play(audio_item.file, item_props, click_offset)
        end
    end
    
    if player and reaper.ImGui_IsItemDeactivated(ctx) then
        if player:isPlaying() then
            player:stop()
        end
    end
    
    -- Get drawing area
    local x, y = item_x, item_y
    local x_max, y_max = item_x_max, item_y_max
    
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    
    -- Draw background
    reaper.ImGui_DrawList_AddRectFilled(draw_list, x, y, x_max, y_max, config.COLORS.WAVEFORM_BACKGROUND)
    
    -- Get peak data
    local pixel_count = math.min(math.floor(w), self.max_pixel_width)
    local data = self:getPeaksFromAudioItem(audio_item, pixel_count)
    
    if data and data.peaks then
        local center_y = y + h / 2
        local scale_y = h * config.WAVEFORM_VERTICAL_SCALE
        
        -- Draw center line
        reaper.ImGui_DrawList_AddLine(draw_list, x, center_y, x_max, center_y, config.COLORS.WAVEFORM_CENTER_LINE, 1)
        
        -- Calculate fade pixels
        local fade_in_pixels = (item_props.fade_in / item_props.item_length) * w
        local fade_out_pixels = (item_props.fade_out / item_props.item_length) * w
        
        -- Draw waveform
        for px = 1, #data.peaks do
            if data.peaks[px] then
                local peak = data.peaks[px]
                
                -- Calculate fade multiplier
                local fade_mult = 1.0
                
                if fade_in_pixels > 0 and px <= fade_in_pixels then
                    fade_mult = px / fade_in_pixels
                end
                
                if fade_out_pixels > 0 and px > (#data.peaks - fade_out_pixels) then
                    local fade_out_progress = (#data.peaks - px) / fade_out_pixels
                    fade_mult = math.min(fade_mult, fade_out_progress)
                end
                
                -- Apply fade to peak values
                local faded_min = peak[1] * fade_mult
                local faded_max = peak[2] * fade_mult
                
                local y_top = center_y - (faded_max * scale_y)
                local y_bottom = center_y - (faded_min * scale_y)
                
                -- Choose color based on mode
                local color
                
                if data.is_spectral and data.freq_data and data.freq_data[px] then
                    -- SPECTRAL MODE: Color based on frequency
                    local freq = data.freq_data[px]
                    local peak_amplitude = math.max(math.abs(faded_max), math.abs(faded_min))
                    local alpha = lerp(0.4, 1.0, peak_amplitude)
                    alpha = math.min(1.0, alpha)
                    
                    color = GetColorFromFreq(freq, alpha, self.spectral_hue_offset)
                else
                    -- NORMAL MODE: Color based on fade regions
                    color = config.COLORS.WAVEFORM_NORMAL
                    
                    if fade_in_pixels > 0 and px <= fade_in_pixels then
                        color = config.COLORS.WAVEFORM_FADE_IN
                    end
                    
                    if fade_out_pixels > 0 and px > (#data.peaks - fade_out_pixels) then
                        color = config.COLORS.WAVEFORM_FADE_OUT
                    end
                end
                
                -- Draw waveform line
                reaper.ImGui_DrawList_AddLine(
                    draw_list,
                    x + px - 1, y_top,
                    x + px - 1, y_bottom,
                    color,
                    1
                )
            end
        end
        
        -- Draw playback position indicator
        if player and player:isPlaying() then
            local preview_pos = player:getPosition()
            if preview_pos then
                local progress = (preview_pos - source_offset) / item_length
                if progress >= 0 and progress <= 1 then
                    local pos_x = x + (progress * w)
                    reaper.ImGui_DrawList_AddLine(draw_list, pos_x, y, pos_x, y_max, config.COLORS.WAVEFORM_PLAYHEAD, 2)
                end
            end
        end
        
        -- Draw hover position indicator
        if reaper.ImGui_IsItemHovered(ctx) then
            local hover_x = x + (normalized_pos * w)
            reaper.ImGui_DrawList_AddLine(draw_list, hover_x, y, hover_x, y_max, config.COLORS.WAVEFORM_HOVER, 1)
            
            local hover_time = source_offset + (normalized_pos * item_length)
            local time_str = string.format("%.2fs", hover_time)
            reaper.ImGui_DrawList_AddText(draw_list, hover_x + 5, y + 5, 0xFFFFFFFF, time_str)
        end
        
    else
        reaper.ImGui_DrawList_AddText(draw_list, x + 10, y + h/2, config.COLORS.TEXT_ERROR, "Could not load waveform")
    end
    
    reaper.ImGui_EndChild(ctx)
end

-- ==============================================================================
-- CACHE MANAGEMENT
-- ==============================================================================

function WaveformViewer:clearCache()
    self.cache = {}
end

function WaveformViewer:getCacheSize()
    local count = 0
    for _ in pairs(self.cache) do
        count = count + 1
    end
    return count
end

function WaveformViewer:removeCacheItem(filepath)
    local removed = 0
    for key, _ in pairs(self.cache) do
        if key:find(filepath, 1, true) then
            self.cache[key] = nil
            removed = removed + 1
        end
    end
    return removed
end

-- Toggle spectral mode
function WaveformViewer:toggleSpectralMode()
    self.spectral_mode = not self.spectral_mode
    if self.spectral_mode then
        self.spectral_hue_offset = GetSpectralHueOffset()
    end
end

-- Set spectral mode
function WaveformViewer:setSpectralMode(enabled)
    self.spectral_mode = enabled
    if enabled then
        self.spectral_hue_offset = GetSpectralHueOffset()
    end
end

return WaveformViewer