classdef HttpPipeline < handle
    % Apply "handlers" on HttpCall before & after the request/response operation.
    %
    % EXAMPLE:
    %
    %       obj = HttpPipeline();
    %
    %       % Append your own handlers.
    %       %
    %       obj.appendReqHandler = ...  
    %       obj.appendRespHandler = ...  
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
        ReqHandlers = {};
        % cellarray of: @func(httpCall) | {}
        RespHandlers = {};
    end

    methods
        function obj = HttpPipeline(reqHandlers, respHandlers)
            % Convert matlab builtin-types into objects for HTTP-request.
            %
            % INPUT:
            %   reqHandlers: (optional) cellarray of @func(HttpCall) | {}
            %   respHandlers:(optional) cellarray of @func(HttpCall)) | {}
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

            if exist('reqHandlers', 'var')
                obj.ReqHandlers = reqHandlers;
            end
            if exist('respHandlers', 'var')
                obj.RespHandlers = respHandlers;
            end
        end
        
        
        function set.ReqHandlers(obj, c)
            if isempty(c)
                obj.ReqHandlers = {};
            else
                assert(isFuncs(c), ...
                    'Invalid `reqHandlers`!\n  Expected a cell-of-@func, got: %s', c);
                obj.ReqHandlers = c;
            end
        end
        function set.RespHandlers(obj, c)
            if isempty(c)
                obj.RespHandlers = {};
            else
                assert(isFuncs(c), ...
                    'Invalid `respHandlers`!\n  Expected a cell-of-@func, got: %s', c);
                obj.RespHandlers = c;
            end
        end
        
        function appendReqHandler(obj, filtfunc)
            obj.ReqHandlers =  [ obj.ReqHandlers  { filtfunc } ];
        end
        function appendRespHandler(obj, filtfunc)
            obj.RespHandlers =  [ obj.RespHandlers  { filtfunc } ];
        end
        
        function [response, history] = doCall(obj, call)
            % Send the HTTP request and apply request(before) & response(after) handlers on objects involved.
            %
            % INPUT:
            %   reqstruct:  struct(scalar)
            %               Fields from `HttpPipeline.prepareHttpPipeline()`:
            %               uri, method, headers, body, options, reqHandlers, respHandlers
            % OUTPUT:
            % * response: matlab.net.http.ResponseMessage
            % * history: matlab.net.http.LogRecord
        
            validateattributes(call, {'HttpCall'}, {'scalar', 'nonempty'}, ...
                mfilename, 'call');
            
            for f = obj.ReqHandlers
                f{1}(call);
            end
            
            [response, completedRequest, history] = call.Request.send(call.Uri, call.HOptions);
            call.Response = response;
            call.Request = completedRequest;
            call.History = history;
            
            for f = obj.RespHandlers
                f{1}(call);
            end
        end
        
    end
    
    methods (Static)
        function assertHttpOkResponseHandler(call)
            % Scream if HTTP-response not Status==OK.
            %
            % INPUT/OUTPUT:
            %   call: HttpCall
            % NOTES:
            % * Respone-handler for `HttpPipeline()`.
            % RAISE:
            %   DatumEx: last response's Status != OK; the Datum contains the original response.

            response = call.Response;
            if response.StatusCode ~= matlab.net.http.StatusCode.OK
                MWError(call, ...
                    sprintf('HttpError:%s', response.StatusCode), ...
                    '%s(%d) \n\n%s', ...
                    response.StatusCode, response.StatusCode, response.Body).throwAsCaller();
            end
        end

    end
end


function tf = isFuncs(c)
    tf = iscell(c) && all(cellfun(@(x) isa(x, 'function_handle'), c));
end
