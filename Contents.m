% A ([semantic](https://semantic-mediawiki.org)) [MediaWiki](https://www.mediawiki.org) 
% client for [Matlab](https://www.mathworks.com/products/matlab.html).
%
%% Overview
% * The `MWSite` class is the endpoint that does the API calls.
% * The HttpCall & HttpPipe classes form an "pipeline" (influened by 
%   <http://axis.apache.org/axis2/java/core/docs/userguide.html#handlessoap apache axis> 
%   that allows to augment the http operation, not by extending the classes but by 
%   inserting "filter" (callbacks) that intercept the request/reponse before/after the operation.
% 
%% Classes
%   HttpCall    - Matlab's builtin-types converted as HTTP objects that pass through HttpPipe filters.
%   HttpPipe    - Apply "filters" on HttpCall before & after the request/response operation.
%   HttpSession - HttpPipe filters for storing redirects & cookies from requests.
%   MWError     - An exception that keeps the HttpCall related to the cause of the error.
%   MWSite      - The MediaWiki client endpoint.



