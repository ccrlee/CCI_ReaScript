-- @description Helper Functions for Top Tail Script
-- @author Roc Lee
-- @version 0.6

--[[
Read a set of samples from a Reaper Array and return into a table
--]]

dofile(reaper.GetResourcePath()..'/Scripts/X-Raym Scripts/Functions/spk77_Get max peak val and pos from take_function.lua' )


function Msg (param)
    reaper.ShowConsoleMsg(tostring (param).."\n")
end

function Debug(label, param, debug)
    if debug then
        reaper.ShowConsoleMsg(label..': '..tostring(param))
    end
end

function GuiInit(name)
    ctx = reaper.ImGui_CreateContext(name) -- Add VERSION TODO
    FONT = reaper.ImGui_CreateFont('sans-serif', 20) -- Create the fonts you need
    reaper.ImGui_AttachFont(ctx, FONT)-- Attach the fonts you need
    return ctx
end

function GetTakeBoundaries(take)
    local item_pos = reaper.GetMediaItemInfo_Value( item, 'D_POSITION' )
    local item_len = reaper.GetMediaItemInfo_Value( item, 'D_LENGTH' ) 
    local boundary_start = item_pos
    local boundary_end = item_pos + item_len

    return item_pos, item_len, boundary_start, boundary_end
end

function ReadTakeSamples(take, window_size, samplerate, numChannels, read_pos, bufferSize, sampleWriteBuffer)
    
    local accessor = reaper.CreateTakeAudioAccessor( take )
    local sampleReadBuffer = reaper.new_array(bufferSize)
    local write_pos = 0

    local startTime, _, _, endTime = GetTakeBoundaries(take)

    for pos = startTime, endTime, window_size do
        reaper.GetAudioAccessorSamples( accessor, samplerate, numChannels, read_pos, bufferSize, sampleReadBuffer)
        for i = 1, bufferSize do
            sampleWriteBuffer[write_pos+i] = math.abs( sampleReadBuffer[i] )       
        end 
        sampleReadBuffer.clear()
        write_pos = write_pos + bufferSize
        read_pos = read_pos + window_size
    end
    
    reaper.DestroyAudioAccessor( accessor )
    
    return sampleWriteBuffer
end


function gain2DB (input)
    return 20 * math.log(input, 10)
end

function readSamplesForward(readPos, table, func)
    local dB = 0
    local samplePos = 0
    local result = 0
    if readPos >= #table then return end
    
    for i = readPos, #table do
        dB = gain2DB(table[i])    -- value at sample position
        samplePos = i             -- sample position in table
        
        if func(dB) then result = func(db)  break end
    end

    return samplePos, dB
end

function readSamplesBackward(readPos, table, func, shouldExit)
    shouldExit = shouldExit or false
    if shouldExit then return end

    local dB = 0
    local samplePos = 0
    --if readPos >= #table then return end
    for i = #table, 1, -1 do
        dB = gain2DB(table[i])    -- value at sample position
        samplePos = i             -- sample position in table
        
        if func(dB) then result = func(db) break end
    end

    return samplePos, dB, result
end

function mapValues(input, targetMin, targetMax, scaleMin, scaleMax)

    local scaledValue = targetMin + ((targetMax - targetMin)) / ((scaleMax - scaleMin)) * (input - targetMin)

    return scaledValue
end

function SamplePosToTime(samplePos, samplerate)
    return samplePos / samplerate
end

function ReaperNamedCommand(command)
    reaper.Main_OnCommand(reaper.NamedCommandLookup(command), 0)
end

function GetPeakFromRange(readPos, endPos, table, samplerate)
    local offset = 0
    local highest = -60
    local highestPos = 0
    local pointVal = -66
    if readPos >= #table then return 0 end
    if readPos == 0 then readPos = 1 end

    -- Msg('read pos: '..readPos)
    -- Msg('end pos: '..endPos)

    for i = readPos, endPos do
        local input = table[i]
        if(input == nil) then input = 0 end
        local mag2Db = 20 * math.log(input, 10)      -- value at sample position
        offset = i                                      -- sample position in table
        
        -- if mag2Db > -6 then Msg(mag2Db..("pos: "..i)) end
 
        if mag2Db > pointVal then 
            pointVal = mag2Db
            if pointVal > highest then
                highest = pointVal
                highestPos = offset - 1
            end
        end
    end
    offset = highestPos
    pointVal = highest
    local samplePos = offset / samplerate
    local pointPos = samplePos
    -- Msg(pointVal)
    return pointPos, pointVal
end

function ItemSamplePosRangeFromTimeSel(item, samplerate)
    local startPosSamples = 0
    local endPosSamples = 0

    local startPos, endPos = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

    item = reaper.GetSelectedMediaItem(0, 0)
    local take =  reaper.GetActiveTake( item )
    local item_pos, item_len, boundary_start, boundary_end = GetTakeBoundaries(take)

    startPosSamples = math.max(math.floor((startPos - item_pos) * samplerate), 0)
    endPosSamples = math.min(math.ceil((endPos - item_pos) * samplerate), (item_len)* samplerate)
    -- Msg("start pos samp: "..startPosSamples)
    -- Msg("end pos samp: "..endPosSamples)

    return startPosSamples, endPosSamples
end

function DeselectAllPoints(envelope)
    local numPoints = reaper.CountEnvelopePoints(envelope)
    for i = 0, numPoints do
        local _, pos, val, shape, tension, selected = reaper.GetEnvelopePoint(envelope, i)
        if selected then 
                reaper.SetEnvelopePoint(envelope, i, pos, val, shape, tension, false, false)
        end
    end
    reaper.Envelope_SortPoints(envelope) 
end

function DrawPointAtPeakWithinTimeSelection(item, table)
    local take = reaper.GetActiveTake(item)
    local env = reaper.GetTakeEnvelopeByName(take, 'Volume')
    if env == nil then 
        reaper.Main_OnCommand(40693, 0) 
        env = reaper.GetTakeEnvelopeByName(take, 'Volume')
    end -- toggle volume env active
    local take_pcm_source = reaper.GetMediaItemTake_Source(take)
    local itemsamplerate = reaper.GetMediaSourceSampleRate(take_pcm_source)

    local startPos, endPos = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    local item_pos, item_len, boundary_start, boundary_end = GetTakeBoundaries(take)
    
    if startPos < item_pos or endPos > (item_pos + item_len) then 
        reaper.Main_OnCommand(40290, 0) -- set item selection to time selection
        startPos, endPos = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    end
    -- local samplerate = tonumber(reaper.format_timestr_pos( 1-reaper.GetProjectTimeOffset( 0,false ), '', 4 )) -- get sample rate obey project start offset
    local startPosSamples, endPosSamples = ItemSamplePosRangeFromTimeSel(item, itemsamplerate)
    local peakPos, peakVal = GetPeakFromRange(startPosSamples, endPosSamples, table, itemsamplerate)
    local zero = reaper.DB2SLIDER(0)

    if peakVal == nil then peakVal = 0 end
    -- Msg("peak val: "..(peakVal))
    peakVal = reaper.DB2SLIDER(peakVal)
    -- Msg("peak pos: "..peakPos)
    -- Msg("peak pos offset: "..peakPos+(startPos-item_pos))

    DeselectAllPoints(env)
    
    reaper.InsertEnvelopePoint(env, (startPos-item_pos), zero, 5, -0.35, false, true)
    reaper.InsertEnvelopePoint(env, peakPos, peakVal, 5, 0.4, true, true)
    reaper.InsertEnvelopePoint(env, endPos-item_pos, zero, 5, 0, false, true)
    reaper.Envelope_SortPoints( env ) 
end

--_, _, maxPos = get_sample_max_val_and_pos(take, false, false, false)

--Msg("max pos: "..maxPos)


--- bug if rate not 1 then points drawn weird