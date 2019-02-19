% A ([semantic](https://semantic-mediawiki.org)) [MediaWiki](https://www.mediawiki.org) 
% client for [Matlab](https://www.mathworks.com/products/matlab.html).
%
%% Overview
% * The <MWSite> class is the endpoint doing the API calls.
% * The <HttpCall> & <HttpPipeline> classes form an "pipeline" that allows to augment 
%   the http operation by inserting "filter" (callbacks) that intercept 
%   the request/reponse before/after the operation.
%   See also <http://axis.apache.org/axis2/java/core/docs/userguide.html#handlessoap apache axis>
% * <HttpSession> has been implemented as filters.
% 
%% Classes
%   HttpCall     - Matlab's builtin-types converted as HTTP objects that pass through HttpPipeline filters.
%   HttpPipeline - Apply "filters" on HttpCall before & after the request/response operation.
%   HttpSession  - HttpPipeline filters for storing redirects & cookies from requests.
%   MWError      - An exception that keeps the HttpCall related to the cause of the error.
%   MWSite       - The MediaWiki client endpoint.
%
%% Other files
%   CHANGES.md  - Changelog of this project.
%   README.md   - Project's documentation & home page.
%   LICENSE.txt - Project's License (EUPL 1.2).
%   Contents.mt - this file


