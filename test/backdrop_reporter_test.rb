require 'minitest/unit'
require 'minitest/autorun'
require 'open3'
require 'fileutils'
require 'tmpdir'
require 'mocha/setup'

$: << File.dirname(__FILE__)
$: << File.dirname(File.dirname(__FILE__))
require 'helpers/command_line_invoker'
require 'helpers/custom_assertions.rb'
require 'fixtures/akamai_log_file_fixtures'

require 'lib/backdrop_reporter'

class BackdropReporterTest < MiniTest::Unit::TestCase
  include CommandLineInvoker
  include CustomAssertions
  include AkamaiLogFileFixtures

  def setup
    @tempdir = Dir.mktmpdir("backdrop-asset-request-collector-aggregation-test-")
    @logs_dir = "#{@tempdir}/logs"
    @aggregated_dir = "#{@tempdir}/aggregated"
    @posted_dir = "#{@tempdir}/posted"
    @backdrop_endpoint = "example.com"
    FileUtils.mkdir_p(@logs_dir)
    FileUtils.mkdir_p(@aggregated_dir)
    FileUtils.mkdir_p(@posted_dir)
  end

  def teardown
    FileUtils.remove_entry_secure(@tempdir)
  end

  def test_calculates_payload_batches_from_aggregated_data
    make_aggregate_file("2013-07-09.txt", [[5, '/example.com/example.pdf']])
    reporter = BackdropReporter.new(@aggregated_dir, @posted_dir, backdrop_endpoint: @backdrop_endpoint)

    only_expected_payload = [
      {
        _id: "2013-07-09-/example.com/example.pdf",
        _timestamp: "2013-07-09T00:00:00+00:00",
        count: "5"
      }
    ]

    expected_payload_batches = [["2013-07-09", only_expected_payload]]
    assert_equal expected_payload_batches, reporter.payload_batches.to_a
  end

  def test_payload_batches_exclude_already_posted_files
    make_aggregate_file("2013-07-09.txt", [[5, '/example.com/example.pdf']])
    FileUtils.touch(File.join(@posted_dir, "2013-07-09.txt"))
    reporter = BackdropReporter.new(@aggregated_dir, @posted_dir, backdrop_endpoint: @backdrop_endpoint)

    assert_equal [], reporter.payload_batches.to_a
  end

  def test_posts_all_batches_and_touches_a_posting_file
    make_aggregate_file("2013-07-09.txt", [[5, '/example.com/example.pdf']])
    reporter = BackdropReporter.new(@aggregated_dir, @posted_dir, backdrop_endpoint: @backdrop_endpoint)

    _, batch = reporter.payload_batches.first
    RestClient::Request.expects(:execute).with(
      has_entries(
        method: :post,
        url: @backdrop_endpoint,
        payload: MultiJson.dump(batch),
        headers: anything)
    )

    reporter.report!

    assert_similar_time Time.now, File.mtime(File.join(@posted_dir, "2013-07-09.txt"))
  end
end