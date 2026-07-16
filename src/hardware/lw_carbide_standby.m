function response = lw_carbide_standby(config)
%LW_CARBIDE_STANDBY Send the Carbide laser into standby.

response = lw_carbide_request(config, "POST", "Basic/GoToStandby");
end
