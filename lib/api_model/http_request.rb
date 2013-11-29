module ApiModel
  class HttpRequest
    include ApiModel::Initializer

    attr_accessor :path, :method, :options, :api_call, :api_host, :caller, :builder

    def run
      self.api_call = Typhoeus.send(method, full_path, options)
      Response.new self
    end

    def method
      @method ||= :get
    end

    def options
      @options ||= {}
    end

    def full_path
      return path if path =~ /^http/
      "#{api_host}#{path}"
    end

  end
end