# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"
require "thor"

require_relative "generator"

module OpenapiSorbetRails
  class CLI < Thor
    extend T::Sig

    option :output, aliases: "-o", type: :string, desc: "Output directory for generated classes (default: ./output)"
    option :prefix, aliases: "-p", type: :string, desc: "Namespace prefix for generated classes (e.g. Foo::Bar::Api)"
    option :clean, type: :boolean, desc: "Clean up generated classes before generating new ones"
    desc "all API_SPEC_PATH", "Generate Sorbet classes from OpenAPI spec"
    sig { params(api_spec_path: String).void }
    def all(api_spec_path)
      generator = OpenapiSorbetRails::Generator.from_file(
        api_spec_path:,
        output_dir: options[:output] || "#{Dir.pwd}/app/api",
        namespace_prefix: options[:prefix]
      )

      generator.clean_up! if options[:clean]

      generator.generate_all!
    end
  end
end
