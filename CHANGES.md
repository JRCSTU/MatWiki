# Changelog for MatWiki

## 1.0.0: 19 Feb 2019
- RENAME main class MWClient --> MWSite
- REFACT: 
  - SPLIT classes across `HttpPipeline`, `HttpCall`, `HttpSession`(handlers) & `MwSite`,
    so client operations can inspect and modify request & response with callbaks (handlers)
    (ala [apache axis](http://axis.apache.org/axis2/java/core/docs/userguide.html#handlessoap)).
- UNIFY UNIFY HttpCall() + MWSite/apiCall() arg-parsing (uri, uriArgs, method, headers, body, hoptions)
  - `MWSite.apiCall()` accepts kv-pairs (see `HttpCall.inputParser` & `HttpCall` constructor).
- Refact DatumError --> MWError:
  - rename property Datum --> HttpCall.
  - store the hole call instead of just the response/request.
- ENH: Added User-Agent HTTP-header according to https://meta.wikimedia.org/wiki/User-Agent_policy
_ Use GET for tokens, and pass most API params in the URI - keep the post only 
  for password and tokens (by the API recomendation).

## 0.1.1: 18 Feb 2019
- RENAME PROJECT: MatMWClient --> MatWiki
- REFACT:
  - Move HttpOptions from HttpSession-->MWClient.
  - Add utility factory methods to convert matlab builtin-types into HTTP-onjects.
  - User-friendlier client API.

## 0.1.0: 15 Feb 2019
- SUPPORT also MATLAB >= **R2016b**(9.1.x), instead of >= **R2018a**(9.4.x );
  managed to encode POST body-params without relying on `QueryParam`.
- FIX: do not ignore `MWClient.DefaultApiParams`, but add them into URI.
- fix: clean up cookies before `MWClient.login()`, so repeated calls possible.
- fix: do not override given `HttpOptions` in `HttpSession` constructor - now
  possible to debug http-requests and save their `Payload` in `MwClient.History`.  
- enh: `MWClient` accepts `HttpSession` on construction.
- Chore & docs enhancements:
  - add `MWClient.Version` constant to discover project release on runtime.
  - add `.gitignore` and this changelog.
  - some function docs improved.

## 0.0.0: 14 Feb 2019
- allow bots to login;
- run `#ask` semantic-queries.
