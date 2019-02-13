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
        
        
        function response = postParams(obj, body, headers, method)
        % High-level http-request encapsulating a 'struct' body into form-encoded parameters.
        %
        %   body:   struct-array | matlab.net.http.MessageBody | matlab.net.QueryParameter
        %   headers:  (optional) matlab.net.http.HeaderField | [] | {}
        %   method:   (optional) default: 'POST'
        %   response: matlab.net.http.ResponseMessage


            if nargin < 3 || isempty(headers)
                headers = {};
                if nargin < 4 || isempty(method)
                    method = 'POST';
                end
            end
            
            uri = obj.WikiUrl;
            if isstruct(body)
                ctf = matlab.net.http.field.ContentTypeField("application/x-www-form-urlencoded");
                headers = [ctf, headers];
                body = matlab.net.QueryParameter(body);
            end
            request = matlab.net.http.RequestMessage(method, headers, string(body));
            response = obj.Session.sendRequest(uri, request);
            
            if response.StatusCode ~= matlab.net.http.StatusCode.OK
                error('%s: \n\n%s', response.StatusCode, join_cellstr(response.Body));
            else
                % TODO: more MW-error-handling HERE.
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

            response = obj.postParams(params);
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
            
            response = obj.postParams(params);
            login = response.Body.Data.login;
            
            if login.result ~= 'Success'
                error('Wiki(%s): cannot login due to: %s, %s', string(obj.WikiUrl), login.result, login.reason);
            end
        end
        
        
        function response = ask(obj, conditions, printouts, parameters)
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
        %   conditions  = "[[Category:Cars]]|[[Actual mass::+]]";
        %   printouts   = {"Vehicle OEM", "Actual mass"};
        %   parameters  = {"sort%3DActual%20mass", "order%3Ddesc"};
        %   
        %   response = mwclient.ask(conditions, printouts, parameters);
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
            %params.api_version = '3';  % results as json-list on smw-v3.+
            
            response = obj.postParams(params);
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