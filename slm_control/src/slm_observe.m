function slm_observe(ctx, message, fallbackMilliseconds)
%SLM_OBSERVE Pause an example so the SLM pattern can be inspected.

if nargin < 2 || isempty(message)
    message = 'Observe the SLM pattern.';
end
if nargin < 3 || isempty(fallbackMilliseconds)
    fallbackMilliseconds = 15000;
    if isstruct(ctx) && isfield(ctx, 'config') && isfield(ctx.config, 'observationFallbackMs')
        fallbackMilliseconds = ctx.config.observationFallbackMs;
    end
end

fprintf('\n%s\n', message);
fprintf('Press Enter in the MATLAB Command Window to continue.\n');

try
    input('', 's');
catch
    fprintf('Input was not available. Waiting %.1f seconds instead.\n', ...
        fallbackMilliseconds / 1000);
    if nargin >= 1 && ~isempty(ctx)
        slm_wait(ctx, fallbackMilliseconds);
    else
        pause(fallbackMilliseconds / 1000);
    end
end
end
