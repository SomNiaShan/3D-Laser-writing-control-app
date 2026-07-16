function tf = lw_flir_is_connected(flir)
%LW_FLIR_IS_CONNECTED True when a FLIR camera handle is initialized.

tf = isstruct(flir) && isfield(flir, 'isConnected') && logical(flir.isConnected) && ...
    isfield(flir, 'cam') && ~isempty(flir.cam);
end
