# Changelog for MatWiki

## 1.0.0
- PROJECT RENAMED MatMWClient --> MatWiki
- RENAME main class MWClient --> MWSite
- Refactor DatumError --> MWError, iherit from HttpCall; (to contain URL, response & History).
- Added User-Agent HTTP-header according to https://meta.wikimedia.org/wiki/User-Agent_policy
  eg: ``MatWiki/1.0.0-dev0 (https://github.com/JRCSTU/MatWiki) MATLAB/9.5 (R2018b; win64)``
- REFACT: SPLIT classes across `HttpPipe`, `HttpCall`, `HttpSession`(filters) & `MwSite`,
  so client operations can inspect and modify request & response with callbaks (filters).
_ Use GET for tokens, and pass most API params in the URI - keep the post only 
  for password and tokens (by the API recomendation).

## 0.1.0
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

## 0.0.0 
- allow bots to login;
- run `#ask` semantic-queries.
