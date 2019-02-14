classdef MWClient < handle
% Mimic https://github.com/mwclient/mwclient/blob/master/mwclient/client.py
%
%
% EXAMPLE:
%   mw = MWClient('https://www.mediawiki.org/w/api.php');
%   mw.login('botname', 'BOTPaSSwOrd');
%   mw.ask(...);
%
% Author: ankostis

    properties
        % HttpSession
        Session  
        % matlab.net.URI
        WikiUrl   
        % A struct with class-wide params to send on every API call.
        DefaultParams  = struct('format', 'json');  %, 'formatversion', 2, 'errorformat', 'plaintext');
    end
    
    properties (Dependent)
      Cookies
    end
    
    methods
        function obj = MWClient(wikiUrl, defaultApiParams)
        % Initiates internally a new session.
        %
        % INPUT
        %   wikiUrl:    string | matlab.net.URI
        %   defaultApiParams:  struct | []
        %       overrides for the new instance only

            narginchk(1, 2);
            
            if isa(wikiUrl, 'matlab.net.URI')
                obj.WikiUrl = wikiUrl;
            else
                obj.WikiUrl = matlab.net.URI(wikiUrl);
            end
            if exist('defaultApiParams', 'var')
                obj.DefaultParams = defaultApiParams;
            end
            obj.newSession();
        end

        
        function newSession(obj)
        % Forgets old session and initiates a new one;  must call `login()` afterwards.
        
            obj.Session = HttpSession();
        end
        
        
        function cookies = get.Cookies(obj)
        % Fetches stored cookies from the session.
        %
        % INPUT
        %   uri:     matlab.net.URI
        % OUTPUT
        %   cookies: struct.(Name|Value) | []
        
            cookies = obj.Session.getCookiesFor(obj.WikiUrl);
        end
        
        
        function set.Cookies(obj, cookies)
        % Replaces all the cookies of the session.
        %
        % INPUT
        %   uri:     matlab.net.URI
        %   cookies: struct.(Name|Value) | []
        
            obj.Session.setCookiesFor(obj.WikiUrl, cookies);
        end
        
        
        function response = callApi(obj, varargin)
        % Http-request with MW-error handling that preserves the response for examination.
        %
        % SYNTAX
        %   response = api(obj, body, headers, method)
        % INPUT
        %   - body:     {optional) string | struct | matlab.net.(QueryParameter | http.MessageBody)
        %   - headers:  (optional) matlab.net.http.HeaderField | [] | {}
        %   - method:   (optional) default: GET if `body` is empty, POST otherwise.
        % OUTPUT
        %   - response: matlab.net.http.ResponseMessage
        % RAISE
        %   - DatumEx: the Datum contains the original response.
        %   - Other http-errors.
        % NOTES
        %   - A struct-body (or QueryParameter s) are posted as urlencoded-form-params.
        %   - On error, retrieve the response using this on the command-line::
        %
        %       MException.last.Datum

            narginchk(1, 4);
            
            uri = obj.WikiUrl;
            response = obj.Session.send(uri, varargin{:});
            result = response.Body.Data;
            apiErr = response.Header.getFields("MediaWiki-API-Error");
            if isfield(result, 'error')
                DatumError(response, 'MWClient:gotError', ...
                    '%s: MediaWiki-API-Error: %s\n\n%s', ...
                    uri, result.error.code, result.error.info).throw();
            elseif ~isempty(apiErr)
                DatumError(response, 'MWClient:APIError', ...
                    '%s: %s\n\n%s', uri, apiErr, response.Body.Data).throw();
            elseif ischar(result) && contains(result, '<title>MediaWiki API help')
                DatumError(response, 'MWClient:gotHelpPage', ...
                    '%s: returned just the help-page! (no `action` given?)', uri).throw();
            end
        end

        
        function token = newToken(obj, type)
        % Asks a new token from MWiki API.
        %
        % INPUT
        %   type:   (optional) csrf(default) | watch | patrol | rollback | userrights | login
        % OUTPUT
        %   token:  str
            
            if nargin < 2 || isempty(type) || ~any(strcmp({'watch', 'patrol', 'rollback', 'userrights', 'login'}, type))
                % The 'csrf' (cross-site request forgery) token introduced in 1.24 replaces
                % the majority of older tokens, like edittoken and movetoken.                
                type = 'csrf'; 
            end 
            
            apirams = obj.DefaultParams;
            apirams.format = 'json';
            apirams.action = 'query';
            apirams.meta = 'tokens';
            apirams.type = type;

            response = obj.callApi(apirams);
            token = response.Body.Data.query.tokens.([type 'token']);
        end
        
            
        function obj = login(obj, user, pswd)
        % Authenticates session with the specified credentials.
        %
        % INPUT
        %   user/pswd:    string
            
            narginchk(3, 3);
            
            apirams = obj.DefaultParams;
            apirams.lgtoken = obj.newToken('login');
            
            apirams.action = 'login';
            apirams.lgdomain = ''; 
            apirams.lgname = user;
            apirams.lgpassword = pswd; 
            
            response = obj.callApi(apirams);
            login = response.Body.Data.login;
            
            if ~strcmp(login.result, 'Success')
                DatumError(response, 'MWClient:loginDenied', ...
                    '%s: cannot login due to: %s, %s', ...
                    string(obj.WikiUrl), login.result, login.reason).throw();
            end
        end
        
        
        function response = askargs(obj, conditions, printouts, parameters)
        % Ask a Semantic MediaWiki query.
        %
        % SYNTAX:
        %   response = askargs(obj, conditions, [printouts, [parameters ]])
        % INPUT:
        %   conditions:     string | cellstr
        %   printouts:      (optional) string | cellstr
        %   parameters:     (optional) string | cellstr
        % OUTPUT:
        %     All search results, A valid query with zero results will not raise.
        % API docs: 
        %   - https://semantic-mediawiki.org/wiki/Ask_API
        %   - https://www.semantic-mediawiki.org/w/api.php?action=help&modules=askargs
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
            
            apirams = obj.DefaultParams;
            apirams.action = 'askargs';
            apirams.conditions = join_cellstr(conditions, '|', 'conditions');
            apirams.printouts = join_cellstr(printouts, '|', 'printouts');
            apirams.parameters = join_cellstr(parameters, '|', 'parameters');
            %apirams.callApi_version = '3';  % results as json-list on smw-v3.+
            
            response = obj.callApi(apirams);
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
