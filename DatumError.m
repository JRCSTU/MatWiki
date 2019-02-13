classdef DatumError < MException
% An exception that can curry an extra "datum" related to the error.
    
    properties
        Datum
    end
    
    methods
        function obj = DatumError(datum, varargin)
            obj@MException(varargin{:});
            obj.Datum = datum;
        end
    end
end