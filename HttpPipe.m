classdef HttpPipe < handle
    % Convert matlab builtin-types to HTTP objects and filter them before/after HTTP request.
    %
    % EXAMPLE:
    %
    %       obj = HttpPipe();
    %
    %       % Append your own filters.
    %       %
    %       obj.appendReqFilter = ...  
    %       obj.appendRespFilter = ...  
    %
    %       httcall = HttpCall(
    %
    %       [response, history] = obj.doCall(obj);
    %
    % 
    % Copyright 2019 European Commission (JRC);
    % Licensed under the EUPL (the 'Licence');
    % You may not use this work except in compliance with the Licence.
    % You may obtain a copy of the Licence at: http://ec.europa.eu/idabc/eupl

    properties
        % cellarray of: @func(httpCall) | {}
        ReqFilters = {};
        % cellarray of: @func(httpCall) | {}
        RespFilters = {};
    end

    methods
        function obj = HttpPipe(reqFilters, respFilters)
            % Convert matlab builtin-types into objects for HTTP-request.
            %
            % INPUT:
            %   reqFilters: (optional) cellarray of @func(HttpCall) | {}
            %   respFilters:(optional) cellarray of @func(HttpCall)) | {}
            % OUTPUT:
            %   reqstruct:  struct(scalar)
            %               With the same-named fields, but wrapped in HTTP-classes,
            %               possibly empty-vectors/cells.
            % NOTES:
            % * On HTTP-error, retrieve the original response using this 
            %     on the command-line::
            %
            %       MException.last.Datum
            %
            % SEE ALSO
            % * HttpCall()

            if exist('reqFilters', 'var')
                obj.ReqFilters = reqFilters;
            end
            if exist('respFilters', 'var')
                obj.RespFilters = respFilters;
            end
        end
        
        
        function set.ReqFilters(obj, c)
            if isempty(c)
                obj.ReqFilters = {};
            else
                assert(isFuncs(c), ...
                    'Invalid `reqFilters`!\n  Expected a cell-of-@func, got: %s', c);
                obj.ReqFilters = c;
            end
        end
        function set.RespFilters(obj, c)
            if isempty(c)
                obj.RespFilters = {};
            else
                assert(isFuncs(c), ...
                    'Invalid `respFilters`!\n  Expected a cell-of-@func, got: %s', c);
                obj.RespFilters = c;
            end
        end
        
        function appendReqFilter(obj, filtfunc)
            obj.ReqFilters =  [ obj.ReqFilters  { filtfunc } ];
        end
        function appendRespFilter(obj, filtfunc)
            obj.RespFilters =  [ obj.RespFilters  { filtfunc } ];
        end
        
        function [response, history] = doCall(obj, call)
            % Send the HTTP request and apply request(before) & response(after) filters on objects involved.
            %
            % INPUT:
            %   reqstruct:  struct(scalar)
            %               Fields from `HttpPipe.prepareHttpPipe()`:
            %               uri, method, headers, body, options, reqFilters, respFilters
            % OUTPUT:
            % * response: matlab.net.http.ResponseMessage
            % * history: matlab.net.http.LogRecord
        
            validateattributes(call, {'HttpCall'}, {'scalar', 'nonempty'}, ...
                mfilename, 'call');
            
            for f = obj.ReqFilters
                f{1}(call);
            end
            
            [response, completedRequest, history] = call.request.send(call.uri, call.options);
            call.response = response;
            call.request = completedRequest;
            call.history = history;
            
            for f = obj.RespFilters
                f{1}(call);
            end
        end
        
    end
    
    methods (Static)
        function assertHttpOkResponseFilter(call)
            % Scream if HTTP-response not Status==OK.
            %
            % INPUT/OUTPUT:
            %   call: HttpCall
            % NOTES:
            % * Respone-filter for `HttpPipe()`.
            % RAISE:
            %   DatumEx: last response's Status != OK; the Datum contains the original response.

            if call.response.StatusCode ~= matlab.net.http.StatusCode.OK
                MWError(response, ...
                    sprintf('HttpError:%s', response.StatusCode), ...
                    '%s(%s): %s(%d) \n\n%s', ...
                    method, uri, response.StatusCode, response.StatusCode, response.Body).throwAsCaller();
            end
        end

    end
end


function tf = isFuncs(c)
    tf = iscell(c) && all(cellfun(@(x) isa(x, 'function_handle'), c));
end
