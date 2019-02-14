classdef DatumError < MException
% An exception that curres an extra "datum" related to the error.
%
% Use the static method below to throw this exception::
%
%       DatumError.error(theDatum, 'some:identifier', 'Description for %s", something);
%
% And contrary to `MException()`, the var-args to the format-string can be many types.
    
    properties
        Datum
    end
    
    methods
        function obj = DatumError(datum, identifier, message, varargin)
        % It uses `sprintf` internally bc MException() constructor accepts only string & scalars.
        
            obj@MException(identifier, ...
                '%s\n\nTIP: to retrieve the `%s` datum saved on the error, use:\n    DatumError.last.Datum', ...
                sprintf(message, varargin{:}), class(datum));
            obj.Datum = datum;
        end
    end
end
