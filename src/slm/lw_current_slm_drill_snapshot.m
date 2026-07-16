function snapshot = lw_current_slm_drill_snapshot()
%LW_CURRENT_SLM_DRILL_SNAPSHOT Read the latest SLM drill snapshot from appdata.

snapshot = struct();
try
    key = lw_slm_drill_snapshot_app_data_key();
    if isappdata(0, key)
        candidate = getappdata(0, key);
        if isstruct(candidate) && isfield(candidate, 'options') && isstruct(candidate.options)
            snapshot = candidate;
        end
    end
catch
    snapshot = struct();
end
end
