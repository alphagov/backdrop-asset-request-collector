BEGIN {
  FS="\t";
  OFS="\t";

  DATE = 1;
  URL = 2;
}

{
  url_counts[$URL] += 1
}

END {
  for (url in url_counts) {
    print url_counts[url], url
  }
}