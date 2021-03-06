require 'minitest/unit'
require 'minitest/autorun'
require 'open3'
require 'fileutils'
require 'tmpdir'
require 'zlib'

$: << File.dirname(__FILE__)
require 'helpers/command_line_invoker'
require 'helpers/custom_assertions'
require 'fixtures/akamai_log_file_fixtures'

class AggregationTest < MiniTest::Unit::TestCase
  include CommandLineInvoker
  include AkamaiLogFileFixtures
  include CustomAssertions

  def setup
    @tempdir = Dir.mktmpdir("backdrop-asset-request-collector-aggregation-test-")
    @logs_dir = "#{@tempdir}/logs"
    @processed_dir = "#{@tempdir}/processed"
    @aggregated_dir = "#{@tempdir}/aggregated"
    FileUtils.mkdir_p(@logs_dir)
    FileUtils.mkdir_p(@aggregated_dir)
  end

  def teardown
    FileUtils.remove_entry_secure(@tempdir)
  end

  def read_gz(gz_file)
    Zlib::GzipReader.open(gz_file) {|f| f.read}
  end

  def test_aggregating_one_log_file_creates_a_file_per_day_with_counts_per_url
    make_logfile("gdslog_184926.esw3c_waf_S.201307092000-2400-1.gz") do
      [asset_line(status: 200, uri: "/example.com/foo.pdf")]
    end
    invoke(%Q{extract_asset_lines}, "", {}, [@logs_dir, @processed_dir])

    invoke(%Q{aggregate}, "", {}, [@processed_dir, @aggregated_dir, '2013-07-09'])

    aggregate_file = File.join(@aggregated_dir, "2013-07-09.txt.gz")
    assert File.exist?(aggregate_file), "#{aggregate_file} should exist"
    assert_equal "1\t/example.com/foo.pdf\n", read_gz(aggregate_file)
  end

  def test_aggregating_multiple_log_files_merges_files_from_one_day_before_and_two_days_after
    target_date = "2013-07-09"
    in_range_dates = ["2013-07-08", target_date, "2013-07-10", "2013-07-11"]
    dates = ["2013-07-07"] + in_range_dates + ["2013-07-12"]
    dates.each do |date|
      file_date = date.gsub(/-/, '')
      make_logfile("gdslog_184926.esw3c_waf_S.#{file_date}2000-2400-1.gz") do
        dates.map do |asset_line_date|
          asset_line(date: asset_line_date, status: 200, uri: "/example.com/foo.pdf")
        end
      end
    end
    invoke(%Q{extract_asset_lines}, "", {}, [@logs_dir, @processed_dir])

    invoke(%Q{aggregate}, "", {}, [@processed_dir, @aggregated_dir, target_date])

    # there will have been one line for target_date in each of the in_range files
    expected_log_line_count = in_range_dates.size

    aggregate_file = File.join(@aggregated_dir, "#{target_date}.txt.gz")
    assert_equal "#{expected_log_line_count}\t/example.com/foo.pdf\n", read_gz(aggregate_file)
  end

  def test_aggregating_does_not_regenerate_if_output_up_to_date
    make_logfile("gdslog_184926.esw3c_waf_S.201307092000-2400-1.gz") { [asset_line(date: "2013-07-09")] }
    aggregate_file = make_aggregate_file("2013-07-09.txt.gz", [])
    aggregate_file_mtime = Time.now + 1000
    FileUtils.touch(aggregate_file, mtime: aggregate_file_mtime)
    assert_similar_time aggregate_file_mtime, File.mtime(aggregate_file)
    invoke(%Q{aggregate}, "", {}, [@processed_dir, @aggregated_dir, '2013-07-09'])
    assert_similar_time aggregate_file_mtime, File.mtime(aggregate_file)
  end
end