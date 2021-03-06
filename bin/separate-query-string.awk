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

function normalise_url(url)
{
  url = url_without_query_string(url)
  sub(/^\/www-origin.production.alphagov.co.uk\//, "www.gov.uk/", url)
  return url
}

# Skip commented lines
/^#/ { next }

# Success lines
$STATUS ~ /^(200|304)$/ && is_asset($URL) {
  print $DATE, normalise_url($URL)
}

# Handle 206 responses
#
# A 206 is a successful response to a partial get request. We've noticed that
# PDF viewers do partial requests to incrementally download a PDF file. It's
# quite common to see several hundred 206 responses for a PDF from the same IP
# address.
$STATUS == "206" && is_asset($URL) {
  partial_responses[$DATE, $IP, normalise_url($URL)] += 1
}

END {
  for (date_ip_url in partial_responses) {
    split(date_ip_url, parts, SUBSEP)
    print parts[1], parts[3]
  }
}