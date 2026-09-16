classdef FakeSlmInitializationSdk < handle
    % Hardware-free SDK resource model used by TestSlmInitialization.
    properties
        Calls = struct('name', {}, 'args', {})
        FailOnce = ''
        ActiveWindows = 900
        ActivePreviews = []
        NextWindowId = 101
        WidthPx = uint32(1920)
        HeightPx = uint32(1080)
    end

    methods
        function varargout = invoke(self, name, varargin)
            self.Calls(end + 1) = struct('name', name, 'args', {varargin});
            if strcmp(self.FailOnce, name)
                self.FailOnce = '';
                error('test:SlmSdkFailure', 'Synthetic SDK failure in %s.', name);
            end

            switch name
                case 'load_heds_types'
                    global heds_types %#ok<GVMIS>
                    heds_types = struct('HEDSSLMPF_None', int32(0));
                case {'heds_sdk_init', 'heds_sdk_print_version'}
                case 'heds_sdk_close_all'
                    self.ActiveWindows = [];
                    self.ActivePreviews = [];
                case 'heds_slmwindow_open'
                    windowId = self.NextWindowId;
                    self.NextWindowId = windowId + 1;
                    self.ActiveWindows(end + 1) = windowId;
                    varargout{1} = windowId;
                case 'heds_slmwindow_slmsetup_add_screen'
                    self.requireWindow(varargin{1});
                case 'heds_slmwindow_slmsetup_apply'
                    self.requireWindow(varargin{1});
                    varargout{1} = [ ...
                        struct('slmwindow_id', varargin{1}, 'slm_id', 1), ...
                        struct('slmwindow_id', varargin{1}, 'slm_id', 2)];
                case 'heds_slm_set_wavelength'
                    self.requireWindow(varargin{1}.slmwindow_id);
                case 'heds_slm_width_px'
                    self.requireWindow(varargin{1}.slmwindow_id);
                    varargout{1} = self.WidthPx;
                case 'heds_slm_height_px'
                    self.requireWindow(varargin{1}.slmwindow_id);
                    varargout{1} = self.HeightPx;
                case 'heds_slmwindow_close'
                    self.requireWindow(varargin{1});
                    self.ActiveWindows(self.ActiveWindows == varargin{1}) = [];
                    self.ActivePreviews(self.ActivePreviews == varargin{1}) = [];
                case 'heds_slmpreview_open'
                    self.requireWindow(varargin{1});
                    self.ActivePreviews(end + 1) = varargin{1};
                case 'heds_slmpreview_set_settings'
                    assert(ismember(varargin{1}, self.ActivePreviews), ...
                        'test:MissingPreview', 'Preview settings require an open preview.');
                case 'heds_slmpreview_close'
                    self.ActivePreviews(self.ActivePreviews == varargin{1}) = [];
                case 'heds_slm_init'
                    error('test:UnsafeInitialization', ...
                        'The convenience initializer hides partially opened window IDs.');
                otherwise
                    error('test:UnexpectedSdkCall', 'Unexpected SDK call: %s.', name);
            end
        end

        function args = argumentsFor(self, name)
            selected = self.Calls(strcmp({self.Calls.name}, name));
            args = {selected.args};
        end
    end

    methods (Access = private)
        function requireWindow(self, windowId)
            assert(ismember(windowId, self.ActiveWindows), ...
                'test:MissingSlmWindow', 'SDK operation requires an open SLM window.');
        end
    end
end
