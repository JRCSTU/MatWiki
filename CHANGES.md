# Changelog for MatWiki

## 0.1.1
- RENAME PROJECT: MatMWClient --> MatWiki
- REFACT: 
  - Move HttpOptions from HttpSession-->MWClient.
  - Add utility factory methods to convert matlab builtin-types into HTTP-onjects.
  - User-friendlier client API.

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
