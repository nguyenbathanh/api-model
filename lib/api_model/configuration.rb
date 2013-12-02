module ApiModel
  class Configuration
    include Initializer

    attr_accessor :host, :json_root

    def self.from_inherited_config(config)
      new config.instance_values.reject {|k,v| v.blank? }
    end
  end

  module ConfigurationMethods
    extend ActiveSupport::Concern

    module ClassMethods

      def reset_api_configuration
        @_api_config = nil
      end

      def api_model_configuration
        @_api_config || superclass.api_model_configuration
      rescue
        @_api_config = Configuration.new
      end

      def api_model
        @_api_config = Configuration.from_inherited_config api_model_configuration
        yield @_api_config
      end

    end
  end
end