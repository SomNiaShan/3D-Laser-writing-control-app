function lw_write_imaging_auto_exposure_scout_rows(rows, scoutFile)
%LW_WRITE_IMAGING_AUTO_EXPOSURE_SCOUT_ROWS Write auto-exposure scout rows to CSV.

if isempty(rows)
    return;
end

writetable(struct2table(rows), scoutFile);
end
