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
    %   - WARN: UNTESTED Matlab < 9.4 (< R2018a) with urlencoded parameters in the POST's body,
    %     where HTTP support for "application/x-www-form-urlencoded" in non excistent!
	%   - Based on https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html

    properties
        % matlab.net.http.HTTPOptions persists across requests to reuse  previous
        % Credentials in it for subsequent authentications
        Options;

        % a containers.Map object where: 
        %   key is uri.Host; 
        %   value is "info" struct containing:
        %       cookies: vector of matlab.net.http.Cookie or empty
        %       uri: target matlab.net.URI if redirect, or empty
        Infos;
    end

    methods
        function obj = HttpSession(varargin)
            % SYNTAX:
            %   obj = HttpSession()
            %   obj = HttpSession(options)

            if verLessThan('matlab', '9.1')
                error('Matlab 9.1 (R2016b) or higher required for HTTP support with cookies.');
            end

            p = inputParser;
            p.addOptional('options', ...
                matlab.net.http.HTTPOptions('ConnectTimeout',20), ...
                @(x) isa(x, 'matlab.net.http.HTTPOptions'));
            p.parse(varargin{:});
            
            obj.Options = p.Results.options;

            obj.Options = matlab.net.http.HTTPOptions('ConnectTimeout',20);
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
        
        
        function [response, history] = sendRequest(obj, uri, request)
            % Low-level matlab.net.HTTP request with permanent-redirection and cookies-store (session).
            %
            % INPUT:
            %   - uri: matlab.net.URI
            %   - request: matlab.net.http.RequestMessage
            % OUTPUT:
            %   - response: matlab.net.http.ResponseMessage
            %   - history: matlab.net.http.LogRecord
            % NOTES:
            %   - Adapted from: https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html
        
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
            [response, ~, history] = request.send(uri, obj.Options);
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
        

        function [response, history] = send(obj, uri, body, headers, method)
        % High-level http-request encapsulating a 'struct' body into form-encoded parameters.
            %
            % INPUT:
            %   - uri:      string | matlab.net.URI
            %   - body:     (optional) string | struct | matlab.net.(QueryParameter | http.MessageBody)
            %   - headers:  (optional) matlab.net.http.HeaderField | [] | {}
            %   - method:   (optional) default: GET if `body` is empty, POST otherwise.
            % OUTPUT:
            %   - response: matlab.net.http.ResponseMessage
            %   - history: matlab.net.http.LogRecord
            % NOTES:
            %   - A struct-body (or QueryParameter s) are posted as urlencoded-form-params.
            %   - On HTTP-error, retrieve the original response using this 
            %     on the command-line::
            %
            %       MException.last.Datum

            if ~exist('body', 'var') || isempty(body)
                body = [];
            end
            if ~exist('method', 'var') || isempty(method)
                if isempty(body)
                    method = 'GET';
                else
                    method = 'POST';
                end
            end
            if ~exist('headers', 'var') || isempty(headers)
                headers = [];
            end
            
            if ~isa(uri, 'matlab.net.URI')
                uri = matlab.net.URI(uri);
            end
            
            if isstruct(body)
                body = matlab.net.QueryParameter(body);
            end
            if isa(body, 'matlab.net.QueryParameter') && verLessThan('matlab', '9.4')
                % TODO: UNTESTED CODE in MATLAB versions < R2017a.
                %
                % In older MATLABs, passing a QueryParameter body did not trigger 
                % payload to be populated as "x-www-form-urlencoded", bc this media-type
                % were not properly registered yet - "application/json" were used instead.
                %
                % So we set body's payload and ContentType explicitly.
                
                % No UTF8 needed since urlencoded.
                bodyBytes = unicode2native(string(body), 'ASCII');
                body = matlab.net.http.MessageBody();
                body.Payload = bodyBytes;
                ctf = matlab.net.http.field.ContentTypeField("application/x-www-form-urlencoded");
                headers = [ctf, headers];
            end
            
            request = matlab.net.http.RequestMessage(method, headers, body);
            [response, history] = obj.sendRequest(uri, request);
            
            if response.StatusCode ~= matlab.net.http.StatusCode.OK
                DatumError(response, ...
                    sprintf('HttpError:%s', response.StatusCode), ...
                    '%s(%s): %s(%d) \n\n%s', ...
                    method, uri, response.StatusCode, response.StatusCode, response.Body).throw();
            end
        end

   end
end
