-- @noindex
-- Clear any regions rendering selected track
-- by William N. Lowe
-- wnlsounddesign.com
ret, marks, regs = reaper.CountProjectMarkers(0)

for ri = 0, regs do
    reaper.SetRegionRenderMatrix(0, ri, reaper.GetSelectedTrack(0, 0), -1)
end

