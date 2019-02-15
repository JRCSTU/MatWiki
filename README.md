| project   | MatMWClient: A (semantic) MediaWiki client for Matlab.  |
|-----------|---------------------------------------------------------|
| release   | 0.0.0                                                   |
| rel_date  | 14 Feb 2019                                             |
| home      | https://github.com/JRCSTU/matmwclient                 |
| maintainer| Kostis Anagnostopoulos (ankostis@gmail.com)             |
| license   | [EUPL 1.2](https://joinup.ec.europa.eu/collection/eupl) |
| copyright | [2019 European Commission](https://ec.europa.eu/jrc/)   |

A ([semantic](https://semantic-mediawiki.org)) [MediaWiki](https://www.mediawiki.org) client for [Matlab](https://www.mathworks.com/products/matlab.html).

## Status
As of Feb 2019, it is in a very early stage, just 3 days of work:
- allow bots to login;
- run `#ask` semantic-queries.

## Notes:
- Not tested for `Matlab-9.4+` (**R2018a** or higher), where HTTP support 
  for `application/x-www-form-urlencoded` were not fully there yet.
- Implemented against `MediaWiki-1.31`.
- Very rudimentary error-handling.
- Http-session handling based on the ["official" sample code](https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html).
- Design influenced by the [_python_ client library](https://github.com/mwclient/mwclient/blob/master/mwclient/client.py).

## Example code:
- Place all the mat-files of this project somewhere in your MATLAB's _search-path_,
- generate a [bot-password with adequate permissions](https://www.mediawiki.org/wiki/Manual:Bot_passwords) for your wiki, and 
- replace your Wiki's URL, user & password in the commands below:

```matlab
  >> url = 'http://some.wiki.org/wiki/api.php';
  >> mw = MWClient(url).login('Ankostis@test','qu8hqc8f07se3ra05ufcn89keecpmgtk');
  >> results = mw.askargs('Category:Cars', 'Vehicle OEM', 'limit=3');
  >> disp(results)
      AR004: [1×1 struct]
      AR005: [1×1 struct]
      AR006: [1×1 struct]
  
  >> disp(mw.History)
    LogRecord with properties:
  
               URI: [1×1 matlab.net.URI]
           Request: [1×1 matlab.net.http.RequestMessage]
       RequestTime: [14-Feb-2019 18:32:22    14-Feb-2019 18:32:23]
          Response: [1×1 matlab.net.http.ResponseMessage]
      ResponseTime: [14-Feb-2019 18:32:23    14-Feb-2019 18:32:23]
       Disposition: Done
         Exception: [0×0 MException]
 
```
