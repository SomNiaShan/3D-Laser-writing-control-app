function presets = lw_carbide_get_presets(config)
%LW_CARBIDE_GET_PRESETS Read the Carbide preset list.

presets = lw_carbide_request(config, "GET", "Advanced/Presets");
end
