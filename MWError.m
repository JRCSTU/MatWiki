classdef MWError < MException
% An exception that keeps the HttpCall related to the cause of the error.
%
% Contrary to `MException()`, the var-args to the format-string can be many types.
%
%
% Copyright 2019 European Commission (JRC);
% Licensed under the EUPL (the 'Licence');
% You may not use this work except in compliance with the Licence.
% You may obtain a copy of the Licence at: http://ec.europa.eu/idabc/eupl
    
    properties
        HCall  % HttpCall
    end
    
    methods
        function obj = MWError(call, identifier, message, varargin)
        % It uses `sprintf` internally bc MException() constructor accepts only string & scalars.
            
            hc = matlab.unittest.diagnostics.ConstraintDiagnostic.getDisplayableString(call);
            try
                method = call.request.Method;
            catch
                method = '<method>';
            end
            obj@MException(identifier, ...
                '%s\n\n+ Related HttpCall (currently at MException.last.HCall):\n  %s(%s))\n%s', ...
                sprintf(message, varargin{:}), string(method), string(call.uri), hc);
            obj.HCall = call;
        end
    end
end
