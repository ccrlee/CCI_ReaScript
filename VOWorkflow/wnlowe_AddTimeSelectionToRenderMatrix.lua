-- @noindex
-- Add Regions in your time selection from the selected track to your Region Render Matrix
-- By William N. Lowe
-- wnlsounddesign.com
StartTime, EndTime = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
ret, marks, regs = reaper.CountProjectMarkers(0)

AddRegions = {}
for i = 0, regs + marks do
    ret, isr, regPos, regEnd, regName, MarInx = reaper.EnumProjectMarkers(i)
    if isr and regPos > StartTime and regPos < EndTime then
        table.insert(AddRegions, MarInx)
    end
end

for ri = 1, #AddRegions do
    reaper.SetRegionRenderMatrix(0, AddRegions[ri],
                                 reaper.GetSelectedTrack(0, 0), 1)
end
reaper.DockWindowRefresh()
