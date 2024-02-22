# typed: true
# frozen_string_literal: true

require_relative "openapi_sorbet_rails/cli"
require_relative "openapi_sorbet_rails/response"
require_relative "openapi_sorbet_rails/schema"
require_relative "openapi_sorbet_rails/tools"
require_relative "openapi_sorbet_rails/version"

module OpenapiSorbetRails
  class Error < StandardError; end

  class SchemaNotFoundError < Error
    def initialize(schema_name)
      super("Schema not found: #{schema_name}")
    end
  end

  class UnsupportedSchemaError < Error
    def initialize(schema)
      super("Unsupported schema:\n#{schema}")
    end
  end
end
