require 'minitest/unit'
require 'minitest/autorun'
require 'open3'

$: << File.dirname(__FILE__)
require 'helpers/command_line_invoker.rb'

module ProcessTestFixtures
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

class ProcessTest < MiniTest::Unit::TestCase
  include CommandLineInvoker
  include ProcessTestFixtures

  def as_output_lines(input_lines)
    input_lines.map do |input_line|
      only_fields(%w{date uri}, input_line)
    end
  end

  def test_only_date_and_uri_output
    lines = invoke("process", [asset_line])
    assert_equal [only_fields(%w{date uri}, asset_line)], lines
  end

  def test_comments_are_skipped
    lines = invoke("process", [comment_line, asset_line, comment_line])
    assert_equal 1, lines.size
  end

  def test_only_asset_lines_are_output
    lines = invoke("process", [asset_line, non_asset_line])
    assert_equal as_output_lines([asset_line]), lines
  end

  def test_query_strings_are_stripped
    (with_query_string, without_query_string) = asset_line_with_and_without_query_string
    lines = invoke("process", [with_query_string, without_query_string])
    assert_equal as_output_lines([without_query_string, without_query_string]), lines
  end

  def test_only_200_and_304_responses_are_output
    lines = invoke("process", [
      asset_line(status: 200),
      asset_line(status: 304),
      asset_line(status: 404)]
    )
    assert_equal 2, lines.size
  end

  def test_206_responses_are_grouped_by_ip_address_and_date
    lines = invoke("process", [
      asset_line(status: 206, ip: '1.1.1.1', date: "2013-07-07"),
      asset_line(status: 206, ip: '1.1.1.1', date: "2013-07-08"),
      asset_line(status: 206, ip: '1.1.1.1', date: "2013-07-08"),
      asset_line(status: 206, ip: '1.1.1.2', date: "2013-07-08")]
    )

    expected = as_output_lines([
      asset_line(date: "2013-07-07"),
      asset_line(date: "2013-07-08"),
      asset_line(date: "2013-07-08")
    ])
    assert_equal expected, lines
  end
end