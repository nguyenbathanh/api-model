require 'active_model'
require 'active_support'
require 'active_support/core_ext'
require 'logger'
require 'hashie'

require 'api_model/initializer'
require 'api_model/http_request'
require 'api_model/response'
require 'api_model/rest_methods'
require 'api_model/configuration'

module ApiModel

  class ResponseBuilderError < StandardError; end

  if defined? Rails
    Log = Rails.logger
  else
    Log = Logger.new STDOUT
  end

  class Base < Hashie::Trash
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Serialization
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks

    extend RestMethods
    include ConfigurationMethods

    # Overrides Hashie::Trash to catch errors from trying to set properties which have not been defined
    # and defines it automatically
    def property_exists?(property_name)
      super property_name
    rescue NoMethodError
      Log.debug "Could not set #{property_name} on #{self.class.name}. Defining it now."
      self.class.property property_name.to_sym
    end
  end

end