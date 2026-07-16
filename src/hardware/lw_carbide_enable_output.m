function response = lw_carbide_enable_output(config)
%LW_CARBIDE_ENABLE_OUTPUT Enable/open the Carbide laser output.

response = lw_carbide_request(config, "POST", "Basic/EnableOutput");
end
