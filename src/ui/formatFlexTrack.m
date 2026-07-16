function trackSize = formatFlexTrack(weight)
trackSize = sprintf('%.4gx', max(weight, eps));
end
