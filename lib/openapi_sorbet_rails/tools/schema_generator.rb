# typed: strict

require "psych"
require "pathname"
require "erb"

require "sorbet-runtime"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/keys"

module OpenapiSorbetRails
  module Tools
    class SchemaGenerator
      extend T::Sig

      sig do
        params(
          api_spec_path: String,
          output_dir: T.any(String, Pathname),
          namespace: String
        ).returns(OpenapiSorbetRails::Tools::SchemaGenerator)
      end
      def self.from_file(api_spec_path:, output_dir:, namespace:)
        api_spec = Psych.load_file(api_spec_path).deep_symbolize_keys

        new(api_spec:, output_dir:, namespace:)
      end

      sig { params(api_spec: T::Hash[Symbol, T.untyped], output_dir: T.any(String, Pathname), namespace: String).void }
      def initialize(api_spec:, output_dir:, namespace:)
        @api_spec = api_spec

        @output_dir = T.let(output_dir.is_a?(String) ? Pathname(output_dir) : output_dir, Pathname)
        @namespace = T.let(namespace, String)
      end

      sig { void }
      def generate_all!
        @namespace.split("::").inject(nil) do |namespace, part|
          [namespace, part].compact.join("::").tap do
            create_empty_module_file(_1)
          end
        end

        @api_spec.dig(:components, :schemas).each do |name, schema|
          generate_schema(schema, @namespace, name.to_s)
        end
      end

      sig { params(schema_name: String).void }
      def generate!(schema_name)
        name = schema_name.camelize

        schema = @api_spec.dig(:components, :schemas, name.to_sym)

        raise OpenapiSorbetRails::SchemaNotFoundError, schema_name if schema.nil?

        @namespace.split("::").inject(nil) do |namespace, part|
          [namespace, part].compact.join("::").tap do
            create_empty_module_file(_1)
          end
        end

        generate_schema(schema, @namespace, name)
      end

      sig { void }
      def clean_up!
        # Remove all generated schema files
        Dir.glob(@output_dir.join("**/*.rb").to_s).each do |file|
          warn "Removing: #{file}"
          File.delete(file)
        end
      end

      private

      sig do
        params(
          schema: T::Hash[Symbol, T.untyped],
          namespace: String,
          name: String,
          create_primitive: T::Boolean
        ).returns(String)
      end
      def generate_schema(schema, namespace, name, create_primitive: true)
        spec_doc = Psych.dump(schema.deep_stringify_keys, header: false, indentation: 2)
        class_name = "#{namespace}::#{name}"

        case schema
        in { type: "number" }
          return "Float" unless create_primitive

          create_primitive_class_file(class_name, "Float", spec_doc)
        in { type: "integer" }
          return "Integer" unless create_primitive

          create_primitive_class_file(class_name, "Integer", spec_doc)
        in { type: "string" }
          return "String" unless create_primitive

          create_primitive_class_file(class_name, "String", spec_doc)
        in { type: "boolean" }
          return "T::Boolean" unless create_primitive

          create_primitive_class_file(class_name, "T::Boolean", spec_doc)
        in { type: "null" }
          return "NilClass" unless create_primitive

          create_primitive_class_file(class_name, "NilClass", spec_doc)
        in { type: "object" }
          property_types = schema[:properties].to_h do |property_name, property_schema|
            type = generate_schema(property_schema, class_name, property_name.to_s.camelize, create_primitive: false)

            [
              property_name,
              {
                type: type.tap { break "T.nilable(#{_1})" unless schema[:required].to_a.include?(property_name.to_s) },
                primitive: ["Float", "Integer", "String", "T::Boolean", "NilClass"].include?(type)
              }
            ]
          end

          create_object_class_file(class_name, property_types, spec_doc)
        in { oneOf: child_schemas }
          type = child_schemas.map.with_index(1) do |child_schema, index|
            generate_schema(child_schema, class_name, "OneOf#{index}", create_primitive: false)
          end.then { "T.any(#{_1.join(", ")})" }

          create_oneof_class_file(class_name, type, spec_doc)
        in { allOf: child_schemas }
          child_types = child_schemas.map.with_index(1) do |child_schema, index|
            [
              "all_of#{index}",
              generate_schema(child_schema, class_name, "AllOf#{index}")
            ]
          end.to_h

          create_allof_class_file(class_name, child_types, spec_doc)
        in { type: "array" }
          item_type = generate_schema(schema[:items], class_name, "Item", create_primitive: false)

          # Create empty module file for item type unless it's a primitive type or $ref
          create_empty_module_file(class_name) if item_type == "#{class_name}::Item"

          return "T::Array[#{item_type}]"
        in { "$ref": schema_ref }
          return "#{@namespace}::#{schema_ref.split("/").last}"
        else
          raise OpenapiSorbetRails::UnsupportedSchemaError, schema
        end

        class_name
      end

      sig { params(module_name: String).void }
      def create_empty_module_file(module_name)
        file_content = ERB.new(File.read(template_path("empty_module")), trim_mode: "-").result(binding)

        write_module_file(module_name, file_content)
      end

      sig { params(class_name: String, type: String, spec_doc: String).void }
      def create_primitive_class_file(class_name, type, spec_doc)
        file_content = ERB.new(File.read(template_path("primitive")), trim_mode: "-").result(binding)

        write_module_file(class_name, file_content)
      end

      sig { params(class_name: String, property_types: T::Hash[Symbol, String], spec_doc: String).void }
      def create_object_class_file(class_name, property_types, spec_doc)
        file_content = ERB.new(File.read(template_path("object")), trim_mode: "-").result(binding)

        write_module_file(class_name, file_content)
      end

      sig { params(class_name: String, type: String, spec_doc: String).void }
      def create_oneof_class_file(class_name, type, spec_doc)
        file_content = ERB.new(File.read(template_path("oneof")), trim_mode: "-").result(binding)

        write_module_file(class_name, file_content)
      end

      sig { params(class_name: String, properties: T::Hash[Symbol, String], spec_doc: String).void }
      def create_allof_class_file(class_name, properties, spec_doc)
        file_content = ERB.new(File.read(template_path("allof")), trim_mode: "-").result(binding)

        write_module_file(class_name, file_content)
      end

      sig { params(module_name: String, file_content: String).void }
      def write_module_file(module_name, file_content)
        file_path = @output_dir.join("#{module_name.to_s.underscore}.rb")

        FileUtils.mkdir_p(file_path.dirname)
        File.write(file_path, file_content)

        warn "Generated: #{module_name} => #{file_path}"
      end

      sig { params(name: String).returns(Pathname) }
      def template_path(name)
        Pathname.new(__dir__).join("templates/schema/#{name}.rb.erb")
      end
    end
  end
end
