classdef HttpSession < handle
    % Adapted from: https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html
    % Works only under R2018b due to unsupported ContentTypeField("application/x-www-form-urlencoded")!

    properties
        % matlab.net.http.HTTPOptions persists across requests to reuse  previous
        % Credentials in it for subsequent authentications
        Options = matlab.net.http.HTTPOptions('ConnectTimeout',20);

        % a containers.Map object where: 
        %   key is uri.Host; 
        %   value is "info" struct containing:
        %       cookies: vector of matlab.net.http.Cookie or empty
        %       uri: target matlab.net.URI if redirect, or empty
        Infos = containers.Map;
    end

    methods
        function response = sendRequest(obj, uri, request)
        % Low-level HTTP request with redirection and authentication cookies (session).
        %   uri: matlab.net.URI
        %   request: matlab.net.http.RequestMessage
        %   response: matlab.net.http.ResponseMessage
        
            host = string(uri.Host); % get Host from URI
            try
                % get info struct for host in map
                info = obj.Infos(host);
                if ~isempty(info.uri)
                    % If it has a uri field, it means a redirect previously
                    % took place, so replace requested URI with redirect URI.
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
        

        function response = send(obj, uri, body, headers, method)
        % High-level http-request encapsulating a 'struct' body into form-encoded parameters.
        %
        % INPUT
        %   - uri:      string | matlab.net.URI
        %   - body:     {optional) string | struct | matlab.net.(QueryParameter | http.MessageBody)
        %   - headers:  (optional) matlab.net.http.HeaderField | [] | {}
        %   - method:   (optional) default: GET if `body` is empty, POST otherwise.
        % OUTPUT
        %   - response: matlab.net.http.ResponseMessage
        % NOTES
        %   - A struct-body (or QueryParameter s) are posted as urlencoded-form-params.
        %   - On HTTP-error, retrieve the original response using this on the command-line::
        %
        %       MException.last.Datum

            if nargin < 3 || isempty(body)
                body = [];
            end
            if nargin < 5 || isempty(method)
                if isempty(body)
                    method = 'GET';
                else
                    method = 'POST';
                end
            end
            if nargin < 4 || isempty(headers)
                headers = [];
            end
            
            if ~isa(uri, 'matlab.net.URI')
                uri = matlab.net.URI(uri);
            end
            
            if isstruct(body)
                ctf = matlab.net.http.field.ContentTypeField("application/x-www-form-urlencoded");
                headers = [ctf, headers];
                body = matlab.net.QueryParameter(body);
            end
            
            request = matlab.net.http.RequestMessage(method, headers, body);
            response = obj.sendRequest(uri, request);
            
            if response.StatusCode ~= matlab.net.http.StatusCode.OK
                dex = DatumError(response, ...
                    sprintf('HttpError:%s', response.StatusCode), ...
                    '%s', sprintf('%s(%s): %s(%d) \n\n%s', ...
                        method, uri, response.StatusCode, response.StatusCode, response.Body));
                throw(dex);
            end
        end

   end
end
