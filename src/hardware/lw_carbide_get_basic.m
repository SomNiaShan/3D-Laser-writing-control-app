function basic = lw_carbide_get_basic(config)
%LW_CARBIDE_GET_BASIC Read the Carbide Basic status JSON.

basic = lw_carbide_request(config, "GET", "Basic");
end
