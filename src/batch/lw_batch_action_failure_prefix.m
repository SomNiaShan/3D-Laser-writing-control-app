function prefix = lw_batch_action_failure_prefix(action)
switch string(action)
    case "addRow"
        prefix = 'Failed to add batch row';
    case "duplicateRow"
        prefix = 'Failed to duplicate batch row';
    case "deleteRow"
        prefix = 'Failed to delete batch row';
    case "moveRow"
        prefix = 'Failed to move batch row';
    case "importCsv"
        prefix = 'Failed to import batch CSV';
    case "exportCsv"
        prefix = 'Failed to export batch CSV';
    case "validateTable"
        prefix = 'Batch validation failed';
    case "generateSweep"
        prefix = 'Failed to generate batch sweep';
    case "connectSlm"
        prefix = 'Failed to connect batch SLM';
    case {"disconnectSlm", "disconnectSlmSilent"}
        prefix = 'Failed to disconnect batch SLM';
    case "previewSelected"
        prefix = 'Failed to preview selected SLM row';
    case "showSelected"
        prefix = 'Failed to show selected SLM row';
    case "startBatch"
        prefix = 'Batch imaging failed';
    otherwise
        prefix = 'Batch action failed';
end
end
