function response = lw_carbide_set_pp_divider(config, ppDivider)
%LW_CARBIDE_SET_PP_DIVIDER Set the Carbide pulse picker divider.

response = lw_carbide_request(config, "PUT", "Basic/TargetPpDivider", round(double(ppDivider)));
end
