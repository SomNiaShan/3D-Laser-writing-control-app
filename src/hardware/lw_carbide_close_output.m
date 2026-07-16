function response = lw_carbide_close_output(config)
%LW_CARBIDE_CLOSE_OUTPUT Close/disable the Carbide laser output.

response = lw_carbide_request(config, "POST", "Basic/CloseOutput");
end
