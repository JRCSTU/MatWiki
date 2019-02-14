classdef MWikiClient < handle
% Mimic https://github.com/mwclient/mwclient/blob/master/mwclient/client.py
% Author: ankostis

    properties
        Session  % HttpSession
        WikiUrl   % matlab.net.URI
    end
    methods
        function obj = MWikiClient(wikiUrl)
        % Initiates internally a new session.
        %
        %   wikiUrl:    string | matlab.net.URI
            
            if isa(wikiUrl, 'matlab.net.URI')
                obj.WikiUrl = wikiUrl;
            else
                obj.WikiUrl = matlab.net.URI(wikiUrl);
            end
            obj.newSession();
        end

        
        function newSession(obj)
        % Forgets old session and initiates a new one;  must call `login()` afterwards.
        
            obj.Session = HttpSession;
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

            uri = obj.WikiUrl;
            response = obj.Session.send(uri, varargin{:});
            result = response.Body.Data;
            apiErr = response.Header.getFields("MediaWiki-API-Error");
            if isfield(result, 'error')
                DatumError(response, 'MWikiClient:gotError', ...
                    '%s: MediaWiki-API-Error: %s\n\n%s', ...
                    uri, result.error.code, result.error.info).throw();
            elseif ~isempty(apiErr)
                    '%s', sprintf('%s: %s\n\n%s', uri, apiErr, response.Body.Data));
                throw(dex);
            elseif ischar(result) && contains(result, '<title>MediaWiki API help')
                    '%s', sprintf('%s: returned the help-page! (no action?)', uri));
                throw(dex);
            end
        end

        
        function token = newToken(obj, type)
        % Asks a new token from MWiki API.
        %
        %   type:   csrf(default) | watch | patrol | rollback | userrights | login
        %   token:  str
            
            if nargin < 2 || isempty(type) || ~any(strcmp({'watch', 'patrol', 'rollback', 'userrights', 'login'}, type))
                % The 'csrf' (cross-site request forgery) token introduced in 1.24 replaces
                % the majority of older tokens, like edittoken and movetoken.                
                type = 'csrf'; 
            end 
            
            params.format = 'json';
            params.action = 'query';
            params.meta = 'tokens';
            params.type = type;

            response = obj.callApi(params);
            token = response.Body.Data.query.tokens.([type 'token']);
        end
        
            
        function response = login(obj, user, pswd)
        % Authenticates session with the specified credentials.
        %
        %   user/pswd:    string
            
            params.lgtoken = obj.newToken('login');
            
            params.format = 'json';
            params.action = 'login';
            params.lgdomain = ''; 
            params.lgname = user;
            params.lgpassword = pswd; 
            
            response = obj.callApi(params);
            login = response.Body.Data.login;
            
            if ~strcmp(login.result, 'Success')
                DatumError(response, 'MWikiClient:loginDenied', ...
                    '%s: cannot login due to: %s, %s', ...
                    string(obj.WikiUrl), login.result, login.reason).throw();
            end
        end
        
        
        function response = askargs(obj, conditions, printouts, parameters)
        % Ask a Semantic MediaWiki query.
        %
        %   conditions:     string | cellstr
        %   printouts:      string | cellstr
        %   parameters:     string | cellstr
        %
        % API docs: 
        %   - https://semantic-mediawiki.org/wiki/Ask_API (askargs)
        %   - https://www.semantic-mediawiki.org/w/api.php?action=help&modules=askargs
        %
        % Return:
        %     All search results, A valid query with zero results will not raise.
        %
        % Examples:
        %   conditions  = {"Category:Cars", "Actual mass::+"};
        %   printouts   = "Actual mass";
        %   parameters  = {"sort%3DActual%20mass", "order%3Ddesc"};
        %   
        %   response = mwclient.askargs(conditions, printouts, parameters);
        %   answers = response.Body.Data.query;
        %   answers = answers.results; % might not be there if empty!
        %
        %     >>>     for title, data in answer.items()
        %     >>>         print(title)
        %     >>>         print(data)
        %
        % Adapted from https://github.com/mwclient/mwclient/blob/030cf8aa3b3a7acc9386412461c62049833d612a/mwclient/client.py#L1087
        
            params.format = 'json';
            params.action = 'askargs';
            params.conditions = join_cellstr(conditions, '|', 'conditions');
            params.printouts = join_cellstr(printouts, '|', 'printouts');
            params.parameters = join_cellstr(parameters, '|', 'parameters');
            %params.callApi_version = '3';  % results as json-list on smw-v3.+
            
            response = obj.callApi(params);
        end
    end
end




function joined = join_cellstr(c, delim, errlabel)
% Joins possibly empty celsstrings, string-arrays or chars.

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
