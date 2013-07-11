BEGIN {
  FS="\t";
  OFS="\t";

  #         1    2    3     4         5      6         7        8          9          10            11        12
  # fields: date time cs-ip cs-method cs-uri sc-status sc-bytes time-taken cs-Referer cs-User-Agent cs-Cookie x-wafinfo
  DATE = 1;
  IP = 3;
  METHOD = 4;
  URL = 5;
  STATUS = 6;
}

function url_without_query_string(url)
{
  if (index(url, "?") > 0) {
    return substr(url, 0, index(url, "?") - 1)
  } else {
    return url
  }
}

function is_asset(url)
{
  return url_without_query_string(url) ~ /\.(pdf|csv|rtf|png|jpg|doc|docx|xls|xlsx|ppt|pptx|zip|rdf|txt|kml|odt|ods|xml|atom)$/
}

# Skip commented lines
/^#/ { next }

# Success lines
$STATUS ~ /^(200|304)$/ && is_asset($URL) {
  $URL = url_without_query_string($URL)
  print $DATE, $URL
}

# Handle 206 responses
#
# A 206 is a successful response to a partial get request. We've noticed that
# PDF viewers do partial requests to incrementally download a PDF file. It's
# quite common to see several hundred 206 responses for a PDF from the same IP
# address.
$STATUS == "206" && is_asset($URL) {
  $URL = url_without_query_string($URL)
  partial_responses[$URL][$IP][$DATE] += 1
}

END {
  for (url in partial_responses) {
    for (ip in partial_responses[url]) {
      for (date in partial_responses[url][ip]) {
        print date, url
      }
    }
  }
}