# typed: strict

require "sorbet-runtime"
require "thor"

require_relative "./tools/schema_generator"

module OpenapiSorbetRails
  class CLI < Thor
    extend T::Sig

    option :schema, aliases: "-s", type: :string, repeatable: true, desc: "Schemas to generate"
    option :output, aliases: "-o", type: :string, desc: "Output directory for generated classes"
    option :namespace, aliases: "-n", type: :string, desc: "Namespace for generated classes"
    option :clean, type: :boolean, desc: "Clean up generated classes before generating new ones"
    desc "schema API_SPEC_PATH", "Generate Sorbet classes from OpenAPI schema"
    sig { params(api_spec_path: String).void }
    def schema(api_spec_path)
      generator = OpenapiSorbetRails::Tools::SchemaGenerator.new(
        api_spec_path:,
        output_dir: options[:output] || "#{Dir.pwd}/output",
        namespace: options[:namespace] || "Schema",
      )

      generator.clean_up! if options[:clean]

      if options[:schema]
        options[:schema].each do |schema_name|
          generator.generate!(schema_name)
        end
      else
        generator.generate_all!
      end
    end
  end
end
