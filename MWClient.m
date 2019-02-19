classdef MWClient < handle
    % MWClient   A MediaWiki client-library.
    % Implemented mostly for semantic searches.
    %
    % REQUIRES:
    % MATLAB *R2016b*(9.1.x) or higher, for string-vectors & proper HTTP support 
    % (e.g. for cookies: https://www.mathworks.com/help/matlab/ref/matlab.net.http.cookieinfo-class.html).
    % 
    % SEE ALSO:
    % * [MediaWiki](https://www.mediawiki.org)
    % * [MediaWiki](https://semantic-mediawiki.org Semantic)
    % * [python's client library](https://github.com/mwclient/mwclient/blob/master/mwclient/client.py)
    %   .
    %
    % EXAMPLE:
    %   >> url = 'http://some.wiki.org/wiki/api.php';
    %   >> mw = MWClient(url).login('Ankostis@test','qu8hqc8f07se3ra05ufcn89keecpmgtk');
    %   >> results = mw.askargs('Category:Cars', 'Vehicle OEM', 'limit=3');
    %   >> disp(jsonencode(results))
    %       AR004: [1×1 struct]
    %       AR005: [1×1 struct]
    %       AR006: [1×1 struct]
    %   
    %   >> disp(mw.History)
    %     LogRecord with properties:
    %   
    %                URI: [1×1 matlab.net.URI]
    %            Request: [1×1 matlab.net.http.RequestMessage]
    %        RequestTime: [14-Feb-2019 18:32:22    14-Feb-2019 18:32:23]
    %           Response: [1×1 matlab.net.http.ResponseMessage]
    %       ResponseTime: [14-Feb-2019 18:32:23    14-Feb-2019 18:32:23]
    %        Disposition: Done
    %          Exception: [0×0 MException]
    %  
    % 
    % Copyright 2019 European Commission (JRC);
    % Licensed under the EUPL (the 'Licence');
    % You may not use this work except in compliance with the Licence.
    % You may obtain a copy of the Licence at: http://ec.europa.eu/idabc/eupl
    % Author: ankostis@gmail.com
    % 

    properties (Constant)
        % Informative, and also used to derive the `UserAgent` header.
        %
        % * [Semantic versioning](https://semver.org/)
        % * [PEP440 versioning](https://www.python.org/dev/peps/pep-0440/)
        % * To DEVs: SYNC it with README.md & CHANGES.md.
        Version = '0.1.1'
        
        % Informative, and also used to derive the `UserAgent` header.
        ProjectHome = 'https://github.com/JRCSTU/MatWiki';
    end
    
    properties
        % HttpSession:
        %   (nonempty) 
        Session  

        % matlab.net.URI:
        %   (nonempty) 
        ApiUri
        
        % matlab.net.http.HTTPOptions:
        %   Class-wide defaults prepended to all HTTP-requests.
        %   Preffer to selectively change them on constructor.
        HOptions = matlab.net.http.HTTPOptions('Authenticate', false);  % Not used for mw-login.

        % matlab.net.http.HeaderField:
        %   HTTP-headers prepended to all HTTP-requests.
        Headers

        % matlab.net.HttpOption:
        % Class-wide params always included in the uri by `callApi()`.
        % * NOTE: pass them on constructor instead of modifying thse ones, class-wide.
        % * WARN: changing any of (json, formatversion, errorformat) will invalidate 
        %   the error-handling of responses in `callApi()`!
        ApiArgs  = {'format', 'json', 'formatversion', 2, 'errorformat', 'plaintext'};

        % matlab.net.http.LogRecord:
        %   For DEBUGGING, the http-conversation for the last high-level method called.
        %   NOTE that the request-bodies are not preserved in `History` (to preserve memory),
        %   unless you set the 'SavePayload' HttpOption to `true`.
        History

        % String send with a repective HTTP-header.
        % You may prefix these infos with those of your derrivative library/project.
        UserAgent = MWClient.makeUserAgent();
    end
    
    properties (Dependent)
      Cookies
    end
    
    methods (Access=protected)
        function kvpairs = parseArgs(obj, vcell)
            % Accept kv-pairs overriding object-props on each `callApi()` or construction.
            %
            % INPUT:
            %   vcell: from `varargin` containing the following kv-pairs.
            % KV-PAIRS ACCEPTED:
            %   Session, HOptions, Headers, ApiArgs
            % RETURN:
            % the struct from `inputPraser.Results`
            %
            % If empty-session given, instanciates a new one.
            p = inputParser;
            p.addParameter('Session', [], @(x) isempty(x) || isa(x, 'HttpSession'));
            p.addParameter('HOptions', obj.HOptions, @HttpSession.makeHOptions);
            p.addParameter('Headers', obj.Headers, @HttpSession.makeHeaders);
            p.addParameter('ApiArgs', obj.ApiArgs, @HttpSession.makeQParams);
            
            p.parse(vcell{:});
            kvpairs = p.Results;
            if isempty(kvpairs.Session)
                kvpairs.Session = HttpSession();
            end
        end
        
        
        function appendHistory(obj, hist)
            obj.History = [obj.History hist];
        end
        
        
        function token = newTokenImpl(obj, type)
            % Asks a new token from MWiki API.
            %
            % INPUT:
            %   type:   |csrf watch patrol rollback userrights login|
            % OUTPUT:
            %   token:  str
            % TODO:
            % * Cache tokens.
            
            apiargs.action = 'query';
            apiargs.meta = 'tokens';
            apiargs.type = type;

            response = obj.callApi([], [], apiargs);
            token = response.Body.Data.query.tokens.([type 'token']);
        end
        
            
        function loginImpl(obj, user, pswd)
            % Authenticates session with the specified credentials.
            %
            % INPUT:
            %   user/pswd:    string
            % THROWS:
            %   DatumError: on any login-error
            
            narginchk(3, 3);
            
            apiargs.lgtoken = obj.newTokenImpl('login');
            apiargs.action = 'login';
            apiargs.lgdomain = ''; 
            apiargs.lgname = user;
            apiargs.lgpassword = pswd; 
            
            response = obj.callApi([], [], apiargs);
            login = response.Body.Data.login;
            
            if ~strcmp(login.result, 'Success')
                DatumError(response, 'MWClient:loginDenied', ...
                    '%s: cannot login due to: %s, %s', ...
                    string(obj.ApiUri), login.result, jsonencode(login.reason)).throw();
            end
        end
        
    end
    
    methods
        function obj = MWClient(ApiUrl, varargin)
            % Set defaults and initiates internally a new session (if none given).
            %
            % SYNTAX:
            %   obj = MWClient(apiUrl, [ kwarg1Name, kwarg1Value, ... ] )
            % INPUT:
            % * apiUrl:     |string , matlab.net.URI|
            %   e.g.: |https://www.semantic-mediawiki.org/w/api.php|
            % KWARGS:
            % Override class-defaults:
            %
            % * Session:  	HttpSession
            %               If empty, a new one is instanciated.
            % * HOptions:  	matlab.net.http.HttpOptions | makeOptions(<any>)
            % * Headers:  	matlab.net.http.HeaderField | makeHeaders(<any>)
            % * ApiArgs:  	HttpSession.makeQParams(<any>)
            
            kvpairs = obj.parseArgs(varargin);
            obj.ApiUri = ApiUrl;
            obj.Session = kvpairs.Session;
            obj.HOptions = kvpairs.HOptions;
            obj.Headers = kvpairs.Headers;
            obj.ApiArgs = kvpairs.ApiArgs;
        end

        
        function set.ApiUri(obj, val)
            obj.ApiUri = matlab.net.URI(val);
            assert(~any(cellfun(@isempty, {obj.ApiUri.Host, obj.ApiUri.Scheme})), ...
                'ApiUrl(%s) missing host or scheme!', obj.ApiUri);
        end
        function set.Session(obj, val)
            if isempty(val)
                val = HttpSession();
            end
            assert(isa(val, 'HttpSession') && ~isempty(val), ...
                'Expected a non-empty `HttpSession`, got `%s`: %s!', class(val), val);
            obj.Session = val;
        end
        function set.HOptions(obj, val)
            obj.HOptions = HttpSession.makeHOptions(val);
        end
        function set.Headers(obj, val)
            obj.Headers = HttpSession.makeHeaders(val);
        end
        function set.ApiArgs(obj, val)
            obj.ApiArgs = HttpSession.makeQParams(val);
        end
        
        
        function cookies = get.Cookies(obj)
            % Fetches stored cookies from the session.
            %
            % INPUT:
            %   uri:     matlab.net.URI
            % OUTPUT:
            %   cookies: struct.(Name|Value) | []
        
            cookies = obj.Session.getCookiesFor(obj.ApiUri);
        end
        
        
        function set.Cookies(obj, cookies)
            % Replaces all the cookies of the session; set [] to clear them.
            %
            % INPUT
            %   uri:     matlab.net.URI
            %   cookies: struct.(Name|Value) | []
        
            obj.Session.setCookiesFor(obj.ApiUri, cookies);
        end
        
        
        function response = callApi(obj, varargin)
            % The HTTP-Gateway with MW-error handling, preserving the response for examination.
            %
            % SYNTAX:
            %   response = callApi(obj, method, headers, body, hoptions)
            % INPUT:
            % * method:   (optional) default: GET if `body` is empty, POST otherwise.
            % * headers:  (optional) matlab.net.http.HeaderField | makeHeaders(<any>)
            % * body:     (optional) matlab.net.http.MessageBody | makeQParams(<any>)
            % * hoptions: (optional) matlab.net.http.HttpOptions | makeHOptions(<any>)
            %       if empty, defaults to `obj.HOptions` - not HttpOptions () empty-costructor.
            % OUTPUT
            % * response: matlab.net.http.ResponseMessage
            % THROWS:
            % * DatumEx: the Datum contains the original response.
            % * Other http-errors.
            % NOTES:
            % * To DEVs: the http-conversation is appended in `History`, for debugging; 
            %     clean it before each high-level operation.
            % * A struct-body (or QueryParameter s) are posted as urlencoded-form-params.
            % * On error, retrieve the response using this on the command-line::
            %
            %       MException.last.Datum

            narginchk(1, 4);
            
            uri = obj.ApiUri;
            uri.Query = [ obj.ApiArgs uri.Query ];

            [response, history] = obj.Session.sendParams(uri, varargin{:});
            obj.appendHistory(history);
            
            result = response.Body.Data;
            apiErr = response.Header.getFields("MediaWiki-API-Error");
            
            if isfield(result, 'errors')
                % If req-param `formatversion!=2` this prop becomes singular: 'error'!
                DatumError(response, 'MWClient:gotError', ...
                    '%s: MediaWiki-API-Error: %s\n\n%s', ...
                    uri, strjoin({result.errors.code}, ', '), jsonencode(result.errors)).throw();
            elseif ~isempty(apiErr)
                DatumError(response, 'MWClient:APIError', ...
                    '%s: %s\n\n%s', uri, apiErr, response.Body.Data).throw();
            elseif isstring(result) && contains(result, '<title>MediaWiki API help')
                DatumError(response, 'MWClient:gotApiHelpPage', ...
                    '%s: returned just the API help-page! (no `action` param given?)', uri).throw();
            end
        end

        
        function token = newToken(obj, type)
            % Asks a new token from MWiki API.
            %
            % INPUT:
            %   type:   (optional) csrf(default) | watch | patrol | rollback | userrights | login
            % OUTPUT:
            %   token:  str
            % NOTES:
            % * Caches tokens.
            
            if nargin < 2 || isempty(type) || ~any(strcmp({'watch', 'patrol', 'rollback', 'userrights', 'login'}, type))
                % The 'csrf' (cross-site request forgery) token introduced in 1.24 replaces
                % the majority of older tokens, like edittoken and movetoken.                
                type = 'csrf'; 
            end 
            
            obj.History = [];
            token = obj.newTokenImpl(type);
        end
        
            
        function obj = login(obj, user, pswd)
            % Authenticates session with the specified credentials.
            %
            % INPUT:
            %   user/pswd:    string
            %  OUTPUT:
            %   obj: myself, for chained invocations.
            % THROWS:
            %   DatumError: on any login-error
            
            % Delete any auth-cookie, or 'api-login-fail-badsessionprovider' error.
            obj.Cookies = [];
            obj.History = [];
            loginImpl(obj, user, pswd);
        end
        
        
        function results = askargs(obj, conditions, printouts, parameters)
            % Ask a Semantic MediaWiki query.
            %
            % SYNTAX:
            %   response = askargs(obj, conditions, [printouts, [parameters ]])
            % INPUT:
            %   conditions:     string | cellstr
            %   printouts:      (optional) string | cellstr
            %   parameters:     (optional) string | cellstr
            % OUTPUT:
            %   results: struct
            %       all results (valid query with zero results will not raise).
            % API docs: 
            % * https://semantic-mediawiki.org/wiki/Ask_API
            % * https://www.semantic-mediawiki.org/w/api.php?action=help&modules=askargs
            % EXAMPLE:
            %   conditions  = {"Category:Cars", "Actual mass::+"};
            %   printouts   = "Actual mass";
            %   parameters  = {"sort%3DActual%20mass", "order%3Ddesc"};
            %   
            %   response = mwclient.askargs(conditions, printouts, parameters);
            %   items = response.Body.Data.query.results;  % Might not be there if empty!
            %
            %    for i = items
            %        disp(i);
            %    end
            %
            % Adapted from https://github.com/mwclient/mwclient/blob/030cf8aa3b3a7acc9386412461c62049833d612a/mwclient/client.py#L1087
        
            narginchk(2, 4);
            if ~exist('printouts', 'var') || isempty(printouts)
                printouts = '';
            end
            if ~exist('parameters', 'var') || isempty(parameters)
                parameters = '';
            end
            
            apiargs.action = 'askargs';
            apiargs.conditions = join_cellstr(conditions, '|', 'conditions');
            apiargs.printouts = join_cellstr(printouts, '|', 'printouts');
            apiargs.parameters = join_cellstr(parameters, '|', 'parameters');
            %apiargs.callApi_version = '3';  % results as json-list on smw-v3.+
            
            obj.History = [];
            response = obj.callApi([], [], apiargs);
            
            results = response.Body.Data.query.results;
        end
    end
    
    
    methods (Static)
        function value = makeUserAgent()
            % The string to append on each api-call.
            %
            % See also https://meta.wikimedia.org/wiki/User-Agent_policy
            % See also https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent
            vinfos = ver();
            m.prog = vinfos.Name;
            m.mver = vinfos.Version;
            m.rel = version('-release');
            m.arch = computer('arch');
            value = sprintf('MatWiki/%s (%s) %s/%s (R%s; %s)', ...
                MWClient.Version, MWClient.ProjectHome, m.prog, m.mver, m.rel, m.arch);
        end
    end
end




function joined = join_cellstr(c, delim, errlabel)
    % Joins possibly empty celsstrings, string-arrays or chars.

    narginchk(3, 3);
    
    if iscellstr(c) || isstring(c)
        joined = strjoin(c, delim);
    elseif ischar(c)
        joined = c;
    elseif isempty(c)
        joined = '';
    else
        error('Expected string or cellstr for `%s`, was %s: %s', errlabel, class(c), c);
    end
end
