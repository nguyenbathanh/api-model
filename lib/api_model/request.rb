module ApiModel
  class Request
    include ApiModel::Initializer

    attr_accessor :path, :method, :options, :api_call

    def self.api_host=(api_host)
    	@api_host = api_host
    end

    def self.api_host
    	@api_host || ""
    end

    def run
      self.api_call = Typhoeus.send method, full_path, options
    end

    def method
    	@method ||= :get
    end

    def options
    	@options ||= {}
    end

    def full_path
    	return path if path =~ /^http/
    	self.class.api_host + path
    end

  end
end