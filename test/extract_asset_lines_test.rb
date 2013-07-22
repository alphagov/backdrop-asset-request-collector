require 'minitest/unit'
require 'minitest/autorun'
require 'open3'
require 'tmpdir'

$: << File.dirname(__FILE__)
require 'helpers/command_line_invoker.rb'
require 'fixtures/akamai_log_file_fixtures.rb'

class ExtractAssetLinesTest < MiniTest::Unit::TestCase
  include CommandLineInvoker
  include AkamaiLogFileFixtures

  def setup
    @tempdir = Dir.mktmpdir("backdrop-asset-request-collector-extract-asset-lines-test-")
    @logs_dir = "#{@tempdir}/logs"
    FileUtils.mkdir_p(@logs_dir)
  end

  def teardown
    # FileUtils.remove_entry_secure(@tempdir)
  end

  def as_output_lines(input_lines)
    input_lines.map do |input_line|
      only_fields(%w{date uri}, input_line)
    end
  end

  def run_extract_asset_lines(log_lines)
    make_logfile("gdslog_184926.esw3c_waf_S.201307092000-2400-1.gz") { log_lines }
    invoke(%Q{extract_asset_lines}, "", {}, [@logs_dir])
    File.read(File.join(@logs_dir, "processed", "gdslog_184926.esw3c_waf_S.201307092000-2400-1.stats")).split("\n")
  end

  def test_only_date_and_uri_output
    processed_lines = run_extract_asset_lines([asset_line])
    assert_equal [only_fields(%w{date uri}, asset_line)], processed_lines
  end

  def test_comments_are_skipped
    processed_lines = run_extract_asset_lines([comment_line, asset_line, comment_line])
    assert_equal 1, processed_lines.size
  end

  def test_only_asset_lines_are_output
    processed_lines = run_extract_asset_lines([asset_line, non_asset_line])
    assert_equal as_output_lines([asset_line]), processed_lines
  end

  def test_query_strings_are_stripped
    (with_query_string, without_query_string) = asset_line_with_and_without_query_string
    processed_lines = run_extract_asset_lines([with_query_string, without_query_string])
    assert_equal as_output_lines([without_query_string, without_query_string]), processed_lines
  end

  def test_only_200_and_304_responses_are_output
    processed_lines = run_extract_asset_lines([
      asset_line(status: 200),
      asset_line(status: 304),
      asset_line(status: 404)]
    )
    assert_equal 2, processed_lines.size
  end

  def test_206_responses_are_grouped_by_ip_address_and_date
    processed_lines = run_extract_asset_lines([
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
    assert_equal expected.sort, processed_lines.sort
  end
end