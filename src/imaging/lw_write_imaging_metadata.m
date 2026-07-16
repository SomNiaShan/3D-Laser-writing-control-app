function lw_write_imaging_metadata(rows, metadataFile)
%LW_WRITE_IMAGING_METADATA Write 3D imaging metadata rows to CSV.

if isempty(rows)
    return;
end

metadataTable = struct2table(rows);
writetable(metadataTable, metadataFile);
end
