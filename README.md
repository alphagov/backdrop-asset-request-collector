# Backdrop asset request collector

This collector processes akamai log files to extract successful http requests
for assets. By 'asset' we mean any attachment file. Something is identified as
an attachment by the file extension of the file in the URL (the Content-Type
header is not recorded in the akamai logs).

Akamai logs contain the following fields:

* date: YYYY-MM-DD
* time: HH:MM:SS
* cs-ip: nn.nn.nn.nn
* cs-method: {GET|POST|...}
* cs-uri: /www-origin.production.alphagov.co.uk/government/world/organisations
* sc-status: 200 (numerical HTTP status code [1][ref1])
* sc-bytes: 12870 (number of bytes)
* time-taken: 20 (time in milli seconds)
* cs(Referer): "" (double quoted referer url)
* cs(User-Agent): "" (double quoted user agent string)
* cs(Cookie): "" (double quoted cookie string)
* x-wafinfo: "" (double quoted waf status string)

The prefixes 'cs' and 'sc' refer to data flow from client->server and
server->client respectively.

Of the above fields, we're interested in date, cs-method, cs-uri, sc-status.

## References

1. [ref1] [Akamai Control code reference](https://control.akamai.com/core/search/kb_article.search?articleId=4775)
2. [Akamai Log Delivery Service User Guide](https://control.akamai.com/dl/customers/other/LDS/LDS_User_Guide.pdf)
