classdef HttpCall < handle
    % Convert matlab's builtin-types as HTTP objects, and together pass through HttpPipeline handlers.
    %
    % EXAMPLE:
    %
    %       % Define your own handlers.
    %       %
    %       reqHandlers = {...}
    %       respHandlers = {...};
    %       pipeline = HttpPipe(reqHandlers, respHandlers);
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
        Uri         % string | matlab.net.URI
        Request     % matlab.net.http.RequestMessage
        HOptions     % optional) matlab.net.http.HTTPOptions | HttpCall.makeHOptions(<any>)
        Response	% matlab.net.http.ResponseMessage
        History     % matlab.net.http.LogRecord
    end

    methods
        function obj = HttpCall(varargin)
            % Convert matlab builtin-types into objects for HTTP-request.
            %
            % SYNTAX:
            %   HttpCall(kname1, kvalue1, ...)
            % KWPAIRS:
            %   Uri:        (optional) HttpCall.makeUri(<any>)
            %   UriArgs:    (optional) HttpCall.makeQParams(<any>)
            %   Method:     (optional) makeHeaders(<any>)
            %               default: GET if `body` is empty, POST otherwise.
            %   Headers:    (optional) matlab.net.http.HeaderField | HttpCall.makeHeaders(<any>)
            %   Body:       (optional) matlab.net.http.MessageBody | HttpCall.makeQParams(<any>)
            %   HOptions:    (optional) matlab.net.http.HTTPOptions | HttpCall.makeHOptions(<any>)
            %               if empty, defaults to HttpOptions() empty-costructor.
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

            p = HttpCall.inputParser();
            p.parse(varargin{:});
            r = HttpCall.procParserResults(p.Results);

            obj.Uri = r.Uri;
            obj.HOptions = r.HOptions;
            obj.Request = matlab.net.http.RequestMessage(r.Method, r.Headers, r.Body);
        end
        
        function set.Uri(obj, v)
            obj.Uri = HttpCall.makeUri(v);
        end
        function set.Request(obj, v)
            validateattributes(v, {'matlab.net.http.RequestMessage'}, {'scalar', 'nonempty'}, ...
                mfilename, 'Request');
            obj.Request = v;
        end
        function set.HOptions(obj, v)
            obj.HOptions = HttpCall.makeHOptions(v);
        end
        function set.Response(obj, v)
            validateattributes(v, {'matlab.net.http.ResponseMessage'}, {'scalar', 'nonempty'}, ...
                mfilename, 'Response');
            obj.Response = v;
        end
        function set.History(obj, v)
            validateattributes(v, {'matlab.net.http.LogRecord'}, {'scalar', 'nonempty'}, ...
                mfilename, 'History');
            obj.History = v;
        end
        
        function addUriArgs(obj, v, varargin)
            % Appends at the end (or at rthe begining) the given elements
            %
            % SYNTAX:
            %   addUriArgs(obj, elements [,  prepend ])
            % INPUT:
            %   prepend:    (optional) tf
            %               when true, inserts elements at the beggining.
            a = obj.Uri.Query;
            b = HttpCall.makeUri(v);
            obj.Uri.Query = prepend(a, b, varargin{:});
        end
        function addHeaders(obj, v, varargin)
            % Like HttpCall.addUriArgs
            a = obj.Request.Headers;
            b = HttpCall.makeHeaders(v);
            obj.Request.Headers = prepend(a, b, varargin{:});
        end
    end
    
    
    methods (Static)
        function arg = makeUri(arg)
            % Utility to convert matlab builtin types into HTTP objects.
            %
            % INPUT:
            %   arg:    matlab.net.http.URI | str
            %           It MUST contain 
            if ~isa(arg, 'matlab.net.URI')
                arg = matlab.net.URI(arg);
            end
            assert(~any(cellfun(@isempty, {arg.Host, arg.Scheme, arg.Path})), ...
                'missing scheme, host or path!');
        end

        function method = makeMethod(arg)
            % Utility to convert matlab builtin types into HTTP objects.
            %
            % INPUT:
            %   arg:    matlab.net.http.(RequestMethod, RequestLine) | str | []
            %           NOTE that it allows empties, to be resolved when request has (or not) a body.
            
            if ~isempty(arg) && ~isa(arg, 'matlab.net.http.RequestMethod') && ~isa(arg, 'matlab.net.http.RequestLine')
                method = matlab.net.http.RequestMethod(arg);
            end
        end

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
            assert(isscalar(arg), 'Expected HOptions to be a scalar! \n  was: %s', ...
                matlab.unittest.diagnostics.ConstraintDiagnostic.getDisplayableString(arg));
        end
    
        function parser = inputParser()
            % Accept _detailed_ kv-pairs to construct HttpCall.
            %
            % KV-PAIRS ACCEPTED:
            %   HOptions, UriArgs, Headers, BodyArgs
            % RETURN:
            % 	inputParser 
            % WARN: 
            % BETTER use `HttpCall.procParserResults` on its results 
            % (the HttpCall constructor does that).
            % EXAMPLE
            %   p = HttpCall.inputParser();
            %   p.parse(...);
            %   r = HttpCall.procParserResults(p.Results);
            %   r.Method  % never empty.
            %
            % TIP:
            % Prefer simply using the `HttpCall` constructor.
            
            persistent p
            if isempty(p)
                p = inputParser;
                p.addParameter('Uri', '', @HttpCall.makeUri);
                p.addParameter('UriArgs', [], @HttpCall.makeQParams);
                p.addParameter('Method', []);
                p.addParameter('Headers', [], @HttpCall.makeHeaders);
                p.addParameter('Body', []);  % TODO: detect content-providers?
                p.addParameter('HOptions', [], @HttpCall.makeHOptions);
            end
            parser = p;
        end
        
        function results = procParserResults(parser)
            % Post-process `parser.Results` of `HttpCall.inputParser()` to apply complex-logic.
            %
            % POST-PROCESS:
            % * UriArgs overlayed on Uri
            % * empty Method --> Get | POST (if body is empty)
            % * Body/Headers: Matlab < 9.4 code for "application/x-www-form-urlencoded"
            % * empty Method --> Get | POST (if body is empty).
            %
            % TIP:
            % Prefer simply using the `HttpCall` constructor.
            % NOTE:
            % 
            
            results = parser.Results;

            if ~isempty(results.UriArgs)
                results.Uri.Query = [ uri.Query  results.UriArgs ];
            end
            
            body = results.Body;
            
            if any(strcmp(parser.UsingDefaults, 'Method'))
                if isempty(body)
                    method = 'GET';
                else
                    method = 'POST';
                end
                results.Method = matlab.net.http.RequestMethod(method);
            end
            
            headers = results.Headers;

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
            results.Headers = headers;
            results.Body = body;
        end
    end
end


function merged = prepend(a, b, tf)
    if exist('tf', 'var') && logical(tf)
        tmp = a;
        a = b;
        b = tmp;
    end
    merged = [a b];
end
