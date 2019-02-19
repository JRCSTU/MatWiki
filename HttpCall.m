classdef HttpCall < handle
    % Matlab's builtin-types converted as HTTP objects that pass through HttpPipeline filters.
    %
    % EXAMPLE:
    %
    %       % Define your own filters.
    %       %
    %       reqFilters = {...}
    %       respFilters = {...};
    %       pipeline = HttpPipe(reqFilters, respFilters);
    %
    %       call = HttpCall(...);
    %       [response, history] = pipeline.doCall(call);
    %
    % NOTES:
    % * WARN: UNTESTED Matlab < 9.4 (< R2018a) with urlencoded parameters in the POST's body,
    %     where HTTP support for "application/x-www-form-urlencoded" in non excistent!
	% * Based on https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html
    %
    %
    % Copyright 2019 European Commission (JRC);
    % Licensed under the EUPL (the 'Licence');
    % You may not use this work except in compliance with the Licence.
    % You may obtain a copy of the Licence at: http://ec.europa.eu/idabc/eupl

    properties
        uri         % string | matlab.net.URI
        request     % matlab.net.http.RequestMessage
        options     % optional) matlab.net.http.HttpOptions | makeOptions(<any>)
        response	% matlab.net.http.ResponseMessage
        history     % matlab.net.http.LogRecord
    end

    methods
        function obj = HttpCall(uri, method, headers, body, options)
            % Convert matlab builtin-types into objects for HTTP-request.
            %
            % INPUT:
            %   uri:        string | matlab.net.URI
            %   method:     (optional) default: GET if `body` is empty, POST otherwise.
            %   headers:    (optional) matlab.net.http.HeaderField | makeHeaders(<any>)
            %   body:       (optional) matlab.net.http.MessageBody | makeQParams(<any>)
            %   options:    (optional) matlab.net.http.HttpOptions | makeOptions(<any>)
            %               if empty, defaults to HttpOptions () empty-costructor.
            % NOTES:
            % * A struct or QueryParameters as body are POSTed as urlencoded-form-params,
            %   unless ContentType header has already been se by user.
            %
            % EXAMPLES:
            %   [response, history] = HttpCall(url)                          % GET
            %   [response, history] = HttpCall(url, [], {'UserAgent', ...})  % GET
            %   [response, history] = HttpCall(url, [], [], {'p1', 'val1'})  % POST
            %
            % SEE ALSO
            % * HttpPipeline.doCall()

            if verLessThan('matlab', '9.1')
                error('Matlab 9.1 (R2016b) or higher required for HTTP support with cookies.');
            end

            obj.uri = uri;
            
            if exist('options', 'var')
                obj.options = HttpCall.makeHOptions(options);
            end
            
            if ~exist('headers', 'var') || isempty(headers)
                headers = [];
            else
                headers = HttpCall.makeHeaders(headers);
            end
            
            if ~exist('body', 'var') || isempty(body)
                body = [];
            else
                if ~isa(body, 'matlab.net.http.MessageBody')
                    body = HttpCall.makeQParams(body);
                    % body now a matlab.net.QueryParameter

                    if verLessThan('matlab', '9.4')
                        % TODO: UNTESTED CODE in MATLAB versions < R2017a.
                        %
                        % In MATLAB < R2017a, passing a QueryParameter body did not trigger 
                        % payload to be populated as "x-www-form-urlencoded", bc this media-type
                        % were not properly registered yet - "application/json" were used instead.
                        %
                        % So we set body's payload and ContentType explicitly.

                        % No UTF8 needed since urlencoded.
                        bodyBytes = unicode2native(string(body), 'ASCII');
                        body = matlab.net.http.MessageBody();
                        body.Payload = bodyBytes;
                        
                        % Allow user to override ContentType.
                        %
                        if isempty(headers.getFields(matlab.net.http.field.ContentTypeField))
                            ctf = matlab.net.http.field.ContentTypeField("application/x-www-form-urlencoded");
                            headers = headers.addFields(ctf);
                        end
                    end
                end
            end
            
            if ~exist('method', 'var') || isempty(method)
                if isempty(body)
                    method = 'GET';
                else
                    method = 'POST';
                end
            end

            obj.request = matlab.net.http.RequestMessage(method, headers, body);

        end
        
        function set.uri(obj, v)
            if ~isa(v, 'matlab.net.URI')
                v = matlab.net.URI(v);
            end
            obj.uri = v;
        end
        function set.request(obj, v)
            validateattributes(v, {'matlab.net.http.RequestMessage'}, {'scalar', 'nonempty'}, ...
                mfilename, 'request');
            obj.request = v;
        end
        function set.options(obj, v)
            obj.options = HttpCall.makeHOptions(v);
        end
        function set.response(obj, v)
            validateattributes(v, {'matlab.net.http.ResponseMessage'}, {'scalar', 'nonempty'}, ...
                mfilename, 'response');
            obj.response = v;
        end
        function set.history(obj, v)
            validateattributes(v, {'matlab.net.http.LogRecord'}, {'scalar', 'nonempty'}, ...
                mfilename, 'history');
            obj.history = v;
        end
    end
    
    
    methods (Static)
        function headers = makeHeaders(arg)
            % Utility to convert matlab builtin types into HTTP objects.
            %
            % INPUT:
            %   arg:  HeaderField | cell Mx2| string | structarray.(Name, Value) 
            % OUTPUT:
            % headers: matlab.net.http.HeaderField (possibly 0x0)
            % THROWS:
            %   MWError(arg, 'HttpCall:invalidHeadersArg')
            % EXAMPLES:
            %   HttpCall.makeHeaders([]) OR ({}) OR ('')	--> 0x0 HeaderField 
            %   HttpCall.makeHeaders('a')                --> a=
            %   HttpCall.makeHeaders({'a'})              --> a=
            %   HttpCall.makeHeaders(["a", "b"])         --> a=b
            %   HttpCall.makeHeaders({'a', 2, 'c'})      --> 1x2
            %   s = struct("Name", '2', 'Value', "d");
            %   HttpCall.makeHeaders(s)                  --> 1x1
            %   HttpCall.makeHeaders([s s])              --> 1x2
            % NOTE:
            % * don't create dupes!
            % * i hate matlab's type-system.
            
            if isempty(arg) || isstring(arg) && all("" == arg)
                headers = matlab.net.http.HeaderField.empty;
            elseif isa(arg, 'matlab.net.http.HeaderField')
                headers = arg;
            elseif isstruct(arg)
                arg = {arg.Name, arg.Value};
            end
            
            if iscell(arg) || isstring(arg)
                headers = matlab.net.http.HeaderField(arg{:});
            end
            
            if ~exist('headers', 'var')
                headers = matlab.net.http.HeaderField(arg);
            end
        end
        
        
        function params = makeQParams(arg)
            % Utility to convert matlab builtin types into HTTP objects.
            %
            % INPUT:
            %   arg:  QueryParam | cell Mx2| string | struct(scalar)
            % EXAMPLES:
            %   HttpCall.makeQParams([]) OR ({}) OR ('')	--> 0x0 QueryParam
            %   HttpCall.makeQParams({'a'}).string       --> "a"
            %   'a=1'                                   --> a=1
            %   ["a", "b"]                              --> a=b
            %   {'a', 2, 'b', [], "c", ''}              --> a=2&b&c
            %   "a=1&b=2"                               --> a=1&b=2
            %   ["a=1&b=2", "g=5"]                      ==> a%3D1%26b%3D2=g%3D5
            %   {'a=1&b=2', 'g=5'}                      ==> a%3D1%26b%3D2=g%3D5
            %   s = struct("p1", 'val1', 'p2', "Val2");
            %   s                                       --> p1=val1&p2=Val2
            %   [s s]                                   --> 1x2
            % FAILS:
            %   HttpCall.makeQParams({'a', 'b', 'c'})    --> missing "c" calue!
            %   HttpCall.makeQParams([s s])              --> struct must be scalar!
            
            if isempty(arg) || isstring(arg) && all("" == arg)
                params = matlab.net.QueryParameter.empty;
            elseif isa(arg, 'matlab.net.QueryParameter')
                params = arg;
            elseif isStringScalar(arg)
                params = matlab.net.QueryParameter(arg);
            elseif iscell(arg) || isstring(arg)
                params = matlab.net.QueryParameter(arg{:});
            end
            
            if ~exist('params', 'var')
                params = matlab.net.QueryParameter(arg);
            end
        end
        
        
        function params = makeHOptions(arg)
            % Utility to convert matlab builtin types into HTTP objects.
            if isempty(arg) || isstring(arg) && all("" == arg)
                params = [];
            elseif isa(arg, 'matlab.net.http.HTTPOptions')
                params = arg;
            elseif iscell(arg) || isstring(arg)
                params = matlab.net.http.HTTPOptions(arg{:});
            else
                params = matlab.net.http.HTTPOptions(arg);
            end
        end
    end        
end
