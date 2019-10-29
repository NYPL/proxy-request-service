class RequestError < StandardError
  def initialize(msg="Request error")
    super
  end
end

class JobServiceError < StandardError
end
