require 'logger'
require 'rest_client'
require 'multi_json'

class BackdropReporter
  def initialize(aggregated_dir, posted_dir, options = {})
    @aggregated_dir = aggregated_dir
    @posted_dir = posted_dir
    @logger = options[:logger] || Logger.new(nil)
    @backdrop_endpoint = options[:backdrop_endpoint] || raise("must specify backdrop endpoint")
    @bearer_token = options[:bearer_token]
    @timeout = options[:timeout] || 10
    @open_timeout = options[:open_timeout] || 10
  end

  def payload_batches
    Enumerator.new do |yielder|
      Dir[File.join(@aggregated_dir, "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].txt")].reject do |path|
        already_posted?(path)
      end.map do |path|
        file_date = File.basename(path, '.txt')
        data_batch = File.open(path).map do |line|
          count, url = line.strip.split("\t")
          {
            _id: "#{file_date}-#{url}",
            _timestamp: file_date,
            count: count
          }
        end
        yielder << [file_date, data_batch]
      end
    end
  end

  def report!
    @logger.info "Posting to #{@backdrop_endpoint}"
    payload_batches.each do |file_date, batch|
      begin
        @logger.info "Posting #{batch.size} items for #{file_date}.."
        options = {
          content_type: :json,
          accept: :json,
          timeout: @timeout,
          open_timeout: @open_timeout
        }
        options.merge!(authorization: "Bearer #{@bearer_token}") if @bearer_token
        response = RestClient.post(@backdrop_endpoint, MultiJson.dump(batch), options)
        FileUtils.touch(File.join(@posted_dir, "#{file_date}.txt"))
        @logger.info ".. OK"
      rescue RestClient::Exception => e
        @logger.error "FAILED to post #{file_date} because #{e}"
        @logger.error e.response
      end
    end
  end

  def already_posted?(aggregate_file)
    posting_file = File.join(@posted_dir, File.basename(aggregate_file))
    File.exist?(posting_file) && (File.mtime(posting_file) >= File.mtime(aggregate_file))
  end
end