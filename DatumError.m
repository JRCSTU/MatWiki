classdef DatumError < MException
% An exception that keeps a "datum" related to the cause of the error.
%
% Contrary to `MException()`, the var-args to the format-string can be many types.
    
    properties
        Datum
    end
    
    methods
        function obj = DatumError(datum, identifier, message, varargin)
        % It uses `sprintf` internally bc MException() constructor accepts only string & scalars.
        
            obj@MException(identifier, ...
                '%s\n\nTIP: there is a `%s` related to this error:\n    DatumError.last.Datum', ...
                sprintf(message, varargin{:}), class(datum));
            obj.Datum = datum;
        end
    end
end
