require 'minitest/unit'
require 'minitest/autorun'
require 'open3'
require 'fileutils'
require 'tmpdir'
require 'zlib'

$: << File.dirname(__FILE__)
require 'helpers/command_line_invoker'
require 'fixtures/akamai_log_file_fixtures'

class AggregationTest < MiniTest::Unit::TestCase
  include CommandLineInvoker
  include AkamaiLogFileFixtures

  def setup
    @tempdir = Dir.mktmpdir("backdrop-asset-request-collector-aggregation-test-")
    @logs_dir = "#{@tempdir}/logs"
    FileUtils.mkdir_p(@logs_dir)
  end

  def teardown
    # FileUtils.remove_entry_secure(@tempdir)
  end

  def make_logfile(name, &block)
    data = yield.join("\n") + "\n"
    path = "#{@logs_dir}/#{name}"
    File.open(path, 'w') do |f|
      gz = Zlib::GzipWriter.new(f)
      gz.write(data)
      gz.close
    end
  end

  def test_aggregating_one_log_file_creates_a_file_per_day_with_counts_per_url
    make_logfile("gdslog_184926.esw3c_waf_S.201307092000-2400-1.gz") do
      [asset_line(status: 200, uri: "/example.com/foo.pdf")]
    end
    invoke(%Q{extract_asset_lines}, "", {}, [@logs_dir])

    processed_dir = File.join(@logs_dir, "processed")
    aggregate_dir = File.join(@logs_dir, "aggregated")
    invoke(%Q{aggregate}, "", {}, [processed_dir, aggregate_dir, '2013-07-09'])

    aggregate_file = File.join(aggregate_dir, "2013-07-09.txt")
    assert File.exist?(aggregate_file), "#{aggregate_file} should exist"
    assert_equal "1\t/example.com/foo.pdf\n", File.read(aggregate_file)
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
    invoke(%Q{extract_asset_lines}, "", {}, [@logs_dir])

    processed_dir = File.join(@logs_dir, "processed")
    aggregate_dir = File.join(@logs_dir, "aggregated")
    invoke(%Q{aggregate}, "", {}, [processed_dir, aggregate_dir, target_date])

    # there will have been one line for target_date in each of the in_range files
    expected_log_line_count = in_range_dates.size

    aggregate_file = File.join(aggregate_dir, "#{target_date}.txt")
    assert_equal "#{expected_log_line_count}\t/example.com/foo.pdf\n", File.read(aggregate_file)
  end
end