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
require_relative "generator/component_generator"

module OpenapiSorbetRails
  class Generator
    extend T::Sig

    sig do
      params(
        api_spec_path: String,
        output_dir: T.any(String, Pathname),
        namespace_prefix: T.nilable(String)
      ).returns(OpenapiSorbetRails::Generator)
    end
    def self.from_file(api_spec_path:, output_dir:, namespace_prefix:)
      api_spec = Psych.load_file(api_spec_path).deep_symbolize_keys

      new(api_spec:, output_dir:, namespace_prefix:)
    end

    sig do
      params(
        api_spec: T::Hash[Symbol, T.untyped],
        output_dir: T.any(String, Pathname),
        namespace_prefix: T.nilable(String)
      ).void
    end
    def initialize(api_spec:, output_dir:, namespace_prefix:)
      @api_spec = api_spec

      @file_manager = T.let(
        OpenapiSorbetRails::Generator::FileManager.new(
          output_dir: output_dir.is_a?(Pathname) ? output_dir : Pathname.new(output_dir)
        ),
        OpenapiSorbetRails::Generator::FileManager
      )
      @namespace_prefix = T.let(namespace_prefix, T.nilable(String))

      @component_generator = T.let(
        OpenapiSorbetRails::Generator::ComponentGenerator.new(
          api_spec: @api_spec,
          output_dir:,
          namespace_prefix:
        ),
        OpenapiSorbetRails::Generator::ComponentGenerator
      )
    end

    sig { void }
    def generate_all!
      @component_generator.generate_all!
    end

    sig { void }
    def generate_all_responses!
      @component_generator.generate_all_responses!
    end

    sig { params(names: T::Array[Symbol]).void }
    def generate_responses!(names:)
      names.each do |name|
        @component_generator.generate_response!(name:)
      end
    end

    sig { void }
    def generate_all_schemas!
      @component_generator.generate_all_schemas!
    end

    sig { params(names: T::Array[Symbol]).void }
    def generate_schemas!(names:)
      names.each do |name|
        @component_generator.generate_schema!(name:)
      end
    end

    sig { void }
    def clean_up!
      @file_manager.clean_up!
    end
  end
end
