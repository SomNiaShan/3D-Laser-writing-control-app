function response = lw_carbide_apply_selected_preset(config)
%LW_CARBIDE_APPLY_SELECTED_PRESET Apply the currently selected Carbide preset.

response = lw_carbide_request(config, "POST", "Basic/ApplySelectedPreset");
end
