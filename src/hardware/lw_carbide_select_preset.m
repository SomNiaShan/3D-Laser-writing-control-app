function response = lw_carbide_select_preset(config, presetIndex)
%LW_CARBIDE_SELECT_PRESET Set the selected Carbide preset index.

response = lw_carbide_request(config, "PUT", "Basic/SelectedPresetIndex", round(double(presetIndex)));
end
