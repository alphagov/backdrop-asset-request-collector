module AkamaiLogFileFixtures
  def all_log_field_names
    %w{date time ip method uri status bytes time-taken referer user-agent cookie x-wafinfo}
  end

  def log_line(data_overrides = {})
    data = {
      date: "2013-07-09",
      method: "GET",
      uri: "/www-origin.production.alphagov.co.uk/foo.doc",
      status: "200"
    }.merge(data_overrides)
    all_log_field_names.map do |field_name|
      data[field_name.to_sym] || ""
    end.join("\t")
  end

  def comment_line
    "# Comment"
  end

  def asset_line(overrides = {})
    log_line({uri: "/www-origin.production.alphagov.co.uk/foo.doc"}.merge(overrides))
  end

  def non_asset_line
    log_line(uri: "/www-origin.production.alphagov.co.uk/foo")
  end

  def only_fields(fields, log_line)
    values = log_line.split("\t")
    fields.map do |field_name|
      index = all_log_field_names.find_index(field_name) || raise("Invalid field #{field_name}")
      values[index]
    end.join("\t")
  end

  def asset_line_with_and_without_query_string
    [
      log_line(uri: "/www-origin.production.alphagov.co.uk/foo.doc?some_param=yes"),
      log_line(uri: "/www-origin.production.alphagov.co.uk/foo.doc")
    ]
  end
end
