require 'nypl_platform_api_client'

class JobClient
  # POSTs to JobService to create a record, returning the generated id
  def create_job
    resp = platform_client.post 'jobs', '', headers: { 'Content-Type' => 'text/plain' }

    raise JobServiceError.new('JobService response empty when generating id') unless resp.respond_to? :dig

    id = resp.dig 'data', 'id'
    Application.logger.debug "Got response generating jobid: #{resp}"

    raise JobServiceError.new('Could not start job') if id.nil?

    id
  end

  # Get NyplPlatformApiClient instance
  def platform_client
    if @platform_client.nil?
      raise 'Missing config: ENV.NYPL_OAUTH_ID is not set' unless ENV['NYPL_OAUTH_ID']
      raise 'Missing config: ENV.NYPL_OAUTH_SECRET is not set ' unless ENV['NYPL_OAUTH_SECRET']
      raise 'Missing config: ENV.NYPL_OAUTH_URL is not set ' unless ENV['NYPL_OAUTH_URL']
      raise 'Missing config: ENV.PLATFORM_API_BASE_URL is not set ' unless ENV['PLATFORM_API_BASE_URL']

      kms = KmsClient.new
      @platform_client = NyplPlatformApiClient.new({
        client_id: kms.decrypt(ENV['NYPL_OAUTH_ID']),
        client_secret: kms.decrypt(ENV['NYPL_OAUTH_SECRET']),
        oauth_url: ENV['NYPL_OAUTH_URL'],
        log_level: 'error'
      })
    end

    @platform_client
  end

  # POSTs to JobService to create a record, returning the generated id
  def self.generate_job_id
    instance = self.new
    instance.create_job
  end
end
