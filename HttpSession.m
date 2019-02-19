classdef HttpSession < handle
    % HttpPipe filters for storing redirects & cookies from requests.
    %
    % EXAMPLES:
    %   s = HttpSession();
    %   url = 'https://www.mediawiki.org/w/api.php';
    %   p.action = 'query';
    %   p.prop = 'info';
    %   p.titles = 'Main Page';
    %   s.send(url, p);
    % NOTES:
	% * Based on https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html
    %
    %
    % Copyright 2019 European Commission (JRC);
    % Licensed under the EUPL (the 'Licence');
    % You may not use this work except in compliance with the Licence.
    % You may obtain a copy of the Licence at: http://ec.europa.eu/idabc/eupl

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
        
        
        function sessionRequestFilter(obj, httpcall)
            % Apply permanent-redirects and add Set-cookie(session) headers of HTTP-request.
            %
            % INPUT:
            % 	call: HttpCall
            % NOTES:
            % * Request-filter for `HttpPipe`.
            % * Adapted from: https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html
        
            uri = httpcall.uri;
            request = httpcall.request;
            
            host = uri.Host;
            try
                % get info struct for host in map
                info = obj.Infos(host);
                if ~isempty(info.uri)
                    % If it has a uri field, it means redirected previously,
                    % so replace requested URI with redirected one.
                    httpcall.uri = info.uri;
                end
                if ~isempty(info.cookies)
                    % If it has cookies, it means we previously received cookies from this host.
                    % Add Cookie header field containing all of them.
                    httpcall.request = request.addFields(matlab.net.http.field.CookieField(info.cookies));
                end
            catch
                % no previous redirect or cookies for this host
            end

        end
        
        
        function sessionResponseFilter(obj, httpcall)
            % Detect permanent-redirects and update cookies-store (session) from HTTP-response.
            %
            % INPUT:
            % 	call: HttpCall
            % NOTES:
            % * Respone-filter for `HttpPipe`.
            % * Adapted from: https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html

            if httpcall.response.StatusCode ~= matlab.net.http.StatusCode.OK
                return
            end
            
            uri = httpcall.uri; 
            history = httpcall.history;
            
            host = uri.Host;
            try
                info = obj.Infos(host);
            catch
                % no previous redirect or cookies for this host
                info = [];
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
                    obj.Infos(host) = struct('cookies',[],'uri',targetURI);
                else
                    % change URI in info for this host and put it back in map
                    info.uri = targetURI;
                    obj.Infos(host) = info;
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
        
        
        function [response, history] = sendParams(obj, varargin)
            % Utility HTTP-req sending form-encoded BODY-params with session-cookies & redirects.
            %
            % SYNTAX:
            %   function [response, history] = sendParams(obj, uri, method, headers, body, options)
            % INPUT:
            % * uri:      string | matlab.net.URI
            % * method:   (optional) default: GET if `body` is empty, POST otherwise.
            % * headers:  (optional) matlab.net.http.HeaderField | makeHeaders(<any>)
            % * body:     (optional) matlab.net.http.MessageBody | makeQParams(<any>)
            % * options:  (optional) matlab.net.http.HttpOptions | makeOptions(<any>)
            %       if empty, defaults to HttpOptions () empty-costructor.
            %   reqFilters: (optional) cellarray of @func(HttpCall) | {}
            %   respFilters:(optional) cellarray of @func(HttpCall)) | {}
            % OUTPUT:
            % * response: matlab.net.http.ResponseMessage
            % * history: matlab.net.http.LogRecord
            % RAISE:
            %   DatumEx: on Status != OK; the Datum contains the original response.
            % NOTES:
            % * Creates internally a new pipe everytime; PREFER to replicate this method 
            %   in your client code.
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
            
            narginchk(2, 7);
            
            call = HttpCall(varargin{1:min(end, 5)});
            
            if length(varargin) >= 6
                filters = varargin(min(end, 6):min(end, 7));
            else
                filters = {};
            end
            pipe = HttpPipe(filters{:});
            pipe.appendReqFilter(@obj.sessionRequestFilter);
            pipe.appendRespFilter(@obj.sessionResponeFilter);

            [response, history] = pipe.doCall(call);
        end
    end
end
