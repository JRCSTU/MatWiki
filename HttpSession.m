% Copyright 2019 European Commission (JRC);
% Licensed under the EUPL (the 'Licence');
% You may not use this work except in compliance with the Licence.
% You may obtain a copy of the Licence at: http://ec.europa.eu/idabc/eupl

classdef HttpSession < handle
    % EXAMPLES:
    %   s = HttpSession();
    %   url = 'https://www.mediawiki.org/w/api.php';
    %   p.action = 'query';
    %   p.prop = 'info';
    %   p.titles = 'Main Page';
    %   s.send(url, p);
    % NOTES:
    % * WARN: UNTESTED Matlab < 9.4 (< R2018a) with urlencoded parameters in the POST's body,
    %     where HTTP support for "application/x-www-form-urlencoded" in non excistent!
	% * Based on https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html

    properties
        % a containers.Map object where: 
        %   key is uri.Host; 
        %   value is "info" struct containing:
        %       cookies: vector of matlab.net.http.Cookie or empty
        %       uri: target matlab.net.URI if redirect, or empty
        Infos;
    end

    methods
        function obj = HttpSession()
            if verLessThan('matlab', '9.1')
                error('Matlab 9.1 (R2016b) or higher required for HTTP support with cookies.');
            end

            obj.Infos = containers.Map;
        end
        
        
        function cookies = getCookiesFor(obj, uri)
            % Fetches stored cookies for some URL.
            %
            % INPUT:
            %   uri: matlab.net.URI
            % OUTPUT:
            %   cookies: struct.(Name|Value) | []
        
            cookies = [];
            host = string(uri.Host);
            if obj.Infos.isKey(host)
                cookies = obj.Infos(host).cookies;
            end
        end
        
        
        function setCookiesFor(obj, uri, cookies)
            % Replaces all the cookies for some URL.
            %
            % INPUT
            %   uri:     matlab.net.URI
            %   cookies: struct.(Name|Value) | []
        
            host = string(uri.Host);
            obj.Infos(host) = cookies;
        end
        
        
        function [response, history] = sendRequest(obj, uri, request, varargin)
            % Low-level matlab.net.HTTP request with permanent-redirection and cookies-store (session).
            %
            % SYNTAX:
            %   [response, history] = sendRequest(obj, uri, request, [ options, [ consumer ] ])
            %       from matlab.net.http.RequestMessage.send()
            % INPUT:
            % * uri: matlab.net.URI
            % * request: matlab.net.http.RequestMessage
            % OUTPUT:
            % * response: matlab.net.http.ResponseMessage
            % * history: matlab.net.http.LogRecord
            % NOTES:
            % * Adapted from: https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html
        
            host = string(uri.Host);
            try
                % get info struct for host in map
                info = obj.Infos(host);
                if ~isempty(info.uri)
                    % If it has a uri field, it means redirected previously,
                    % so replace requested URI with redirected one.
                    uri = info.uri;
                end
                if ~isempty(info.cookies)
                    % If it has cookies, it means we previously received cookies from this host.
                    % Add Cookie header field containing all of them.
                    request = request.addFields(matlab.net.http.field.CookieField(info.cookies));
                end
            catch
                % no previous redirect or cookies for this host
                info = [];
            end

            % Send request and get response and history of transaction.
            [response, ~, history] = request.send(uri, varargin{:});
            if response.StatusCode ~= matlab.net.http.StatusCode.OK
                return
            end

            % Get the Set-Cookie header fields from response message in
            % each history record and save them in the map.
            arrayfun(@addCookies, history)

            % If the last URI in the history is different from the URI sent in the original 
            % request, then this was a redirect. Save the new target URI in the host info struct.
            targetURI = history(end).URI;
            if ~isequal(targetURI, uri)
                if isempty(info)
                    % no previous info for this host in map, create new one
                    obj.Infos(char(host)) = struct('cookies',[],'uri',targetURI);
                else
                    % change URI in info for this host and put it back in map
                    info.uri = targetURI;
                    obj.Infos(char(host)) = info;
                end
            end
            
            function addCookies(record)
                % Utility to add cookies in Response message in history record
                % to the map entry for the host to which the request was directed.
                %
                ahost = record.URI.Host; % the host the request was sent to
                cookieFields = record.Response.getFields('Set-Cookie');
                if isempty(cookieFields)
                    return
                end
                cookieData = cookieFields.convert(); % get array of Set-Cookie structs
                cookies = [cookieData.Cookie]; % get array of Cookies from all structs
                try
                    % If info for this host was already in the map, add its cookies to it.
                    ainfo = obj.Infos(ahost);
                    ainfo.cookies = [ainfo.cookies cookies];
                    obj.Infos(char(ahost)) = ainfo;
                catch
                    % Not yet in map, so add new info struct.
                    obj.Infos(char(ahost)) = struct('cookies',cookies,'uri',[]);
                end
            end

        end
        

        function [response, history] = sendParams(obj, uri, method, headers, body, options)
            % High-level HTTP-req sending form-encoded BODY-params and raising http-errors.
            %
            % INPUT:
            % * uri:      string | matlab.net.URI
            % * method:   (optional) default: GET if `body` is empty, POST otherwise.
            % * headers:  (optional) matlab.net.http.HeaderField | makeHeaders(<any>)
            % * body:     (optional) matlab.net.http.MessageBody | makeQParams(<any>)
            % * options:  (optional) matlab.net.http.HttpOptions | makeOptions(<any>)
            %       if empty, defaults to HttpOptions () empty-costructor.
            % OUTPUT:
            % * response: matlab.net.http.ResponseMessage
            % * history: matlab.net.http.LogRecord
            % RAISE:
            %   DatumEx: on Status != OK; the Datum contains the original response.
            % NOTES:
            % * A struct or QueryParameters as body are POSTed as urlencoded-form-params,
            %     unless user overrides ContentType header.
            % * On HTTP-error, retrieve the original response using this 
            %     on the command-line::
            %
            %       MException.last.Datum
            % EXAMPLES:
            %   [response, history] = sendParams(url)                          % GET
            %   [response, history] = sendParams(url, [], {'UserAgent', ...})  % GET
            %   [response, history] = sendParams(url, [], [], {'p1', 'val1'})  % POST

            narginchk(2, 6);
            
            if ~isa(uri, 'matlab.net.URI')
                uri = matlab.net.URI(uri);
            end
            
            if ~exist('headers', 'var') || isempty(headers)
                headers = [];
            else
                headers = HttpSession.makeHeaders(headers);
            end
            
            if ~exist('options', 'var') || isempty(options)
                options = [];
            else
                options = HttpSession.makeHOptions(options);
            end
            
            if ~exist('body', 'var') || isempty(body)
                body = [];
            else
                if ~isa(body, 'matlab.net.http.MessageBody')
                    body = HttpSession.makeQParams(body);
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
                        ctf = matlab.net.http.field.ContentTypeField("application/x-www-form-urlencoded");
                        headers = [headers, ctf];  % user can still override
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
            
            request = matlab.net.http.RequestMessage(method, headers, body);
            [response, history] = obj.sendRequest(uri, request, options);
            
            if response.StatusCode ~= matlab.net.http.StatusCode.OK
                DatumError(response, ...
                    sprintf('HttpError:%s', response.StatusCode), ...
                    '%s(%s): %s(%d) \n\n%s', ...
                    method, uri, response.StatusCode, response.StatusCode, response.Body).throw();
            end
        end

    end
    
    methods (Static)
        function headers = makeHeaders(arg)
            % Utility to convert matlab builtin types into HTTP objects.
            %
            % INPUT:
            %   arg:  HeaderField | cell Mx2| string | structarray.(Name, Value) 
            % OUTOUT:
            % headers: matlab.net.http.HeaderField (possibly 0x0)
            % THROWS:
            %   DatumError(arg, 'HttpSession:invalidHeadersArg')
            % EXAMPLES:
            %   HttpSession.makeHeaders([]) OR ({}) OR ('')	--> 0x0 HeaderField 
            %   HttpSession.makeHeaders('a')                --> a=
            %   HttpSession.makeHeaders({'a'})              --> a=
            %   HttpSession.makeHeaders(["a", "b"])         --> a=b
            %   HttpSession.makeHeaders({'a', 2, 'c'})      --> 1x2
            %   s = struct("Name", '2', 'Value', "d");
            %   HttpSession.makeHeaders(s)                  --> 1x1
            %   HttpSession.makeHeaders([s s])              --> 1x2
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
            %   HttpSession.makeQParams([]) OR ({}) OR ('')	--> 0x0 QueryParam
            %   HttpSession.makeQParams({'a'}).string       --> "a"
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
            %   HttpSession.makeQParams({'a', 'b', 'c'})    --> missing "c" calue!
            %   HttpSession.makeQParams([s s])              --> struct must be scalar!
            
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
