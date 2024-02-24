# frozen_string_literal: true
# typed: strict

require "psych"
require "pathname"
require "erb"

require "sorbet-runtime"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/keys"

require_relative "../openapi_sorbet_rails"
require_relative "generator/file_manager"
require_relative "generator/schema_generator"

module OpenapiSorbetRails
  class Generator
    extend T::Sig

    sig do
      params(
        api_spec_path: String,
        output_dir: T.any(String, Pathname),
        namespace: String
      ).returns(OpenapiSorbetRails::Generator)
    end
    def self.from_file(api_spec_path:, output_dir:, namespace:)
      api_spec = Psych.load_file(api_spec_path).deep_symbolize_keys

      new(api_spec:, output_dir:, namespace:)
    end

    sig do
      params(
        api_spec: T::Hash[Symbol, T.untyped],
        output_dir: T.any(String, Pathname),
        namespace: String
      ).void
    end
    def initialize(api_spec:, output_dir:, namespace:)
      @api_spec = api_spec

      @file_manager = T.let(
        OpenapiSorbetRails::Generator::FileManager.new(
          output_dir: output_dir.is_a?(Pathname) ? output_dir : Pathname.new(output_dir)
        ),
        OpenapiSorbetRails::Generator::FileManager
      )
      @namespace = T.let(namespace, String)

      @schema_generator = T.let(
        OpenapiSorbetRails::Generator::SchemaGenerator.new(
          api_spec: @api_spec,
          output_dir:,
          namespace: @namespace
        ),
        OpenapiSorbetRails::Generator::SchemaGenerator
      )
    end

    sig { void }
    def generate_all!
      @api_spec[:components][:schemas].each_key do |schema_name|
        generate_schema!(schema_name)
      end
    end

    sig { params(schema_name: Symbol).void }
    def generate_schema!(schema_name)
      dig_namespace(namespace: @namespace)

      @schema_generator.generate!(name: schema_name)
    end

    sig { void }
    def clean_up!
      @file_manager.clean_up!
    end

    private

    sig { params(namespace: String).returns(String) }
    def dig_namespace(namespace:)
      namespace.split("::").inject(nil) do |namespace, part|
        [namespace, part].compact.join("::").tap do
          @file_manager.create_empty_module_file(_1)
        end
      end
    end
  end
end
