| project    | MatWiki: A (semantic) MediaWiki client for Matlab.      |
|------------|---------------------------------------------------------|
| release    | 1.0.0                                                        |
| rel_date   | 19 Feb 2019                                             |
| home       | https://github.com/JRCSTU/MatWiki                       |
| maintainer | Kostis Anagnostopoulos (ankostis@gmail.com)             |
| license    | [EUPL 1.2](https://joinup.ec.europa.eu/collection/eupl) |
| copyright  | [2019 European Commission](https://ec.europa.eu/jrc/)   |

A ([semantic](https://semantic-mediawiki.org)) [MediaWiki](https://www.mediawiki.org) 
client for [Matlab](https://www.mathworks.com/products/matlab.html).

The difficult part was to make the HTTP-requests with session cookies & redirects...

## Example:
```matlab
>> url = 'http://some.wiki.org/wiki/api.php';
>> mw = MWSite(url).login('Ankostis@test','qu8hqc8f07se3ra05ufcn89keecpmgtk');  % bot password 
>> mw.askargs('Category:Cars', 'Vehicle OEM', 'limit=3')
>> disp(jsonencode(results))
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


## Status:
As of Feb 2019, it is in a very early stage, just a week of work:
- REQUIRES _MATLAB_ >= **R2016b**(9.1.x) for string-vectors & proper HTTP support.
  (e.g. for cookies: https://www.mathworks.com/help/matlab/ref/matlab.net.http.cookieinfo-class.html).
- Features:
  - Allow bots to login.
  - run `#ask` semantic-queries.
  - Rudimentary error-handling.
  - Respects some of WP's UserAgent policies (Valid UserAgent, Easy to Debug).
  - Http machinery implemented as a pipeline of "handlers" (callbacks).
- Not tested for `Matlab-9.4+` (**R2018a** or higher), where HTTP support 
  for `application/x-www-form-urlencoded` were not fully there yet.
- Lightly tested only against `MediaWiki-1.31`.
- Read [Contents](./Contents.m) for an overview of the library code.
- Read also the [Changelog](./CHANGES.md) of the project.


## Installation
- Download the archive of the [latest release](https://github.com/JRCSTU/MatWiki/releases), 
- extract all the files of the archive somewhere in your MATLAB's _search-path_,
- generate a [bot-password with adequate permissions](https://www.mediawiki.org/wiki/Manual:Bot_passwords) for your wiki, and 
- try the sample code in the [README.md](./README.md) and consult [Contents.m](./Contents.m).


## Notes:
- Http-session handling based on MATLAB's ["official" sample code](https://www.mathworks.com/help/matlab/matlab_external/send-http-message.html).
- Design influenced by:
  - [apache axis](http://axis.apache.org/axis2/java/core/docs/userguide.html#handlessoap)
  - [_python_ client library](https://github.com/mwclient/mwclient/blob/master/mwclient/client.py)

