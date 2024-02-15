# typed: strict

require "psych"
require "pathname"
require "erb"

require "sorbet-runtime"
require "active_support/core_ext/string/inflections"

module OpenapiSorbetRails
  module Tools
    class SchemaGenerator
      extend T::Sig

      sig { params(api_spec_path: T.any(String, Pathname), output_dir: T.any(String, Pathname), namespace: String).void }
      def initialize(api_spec_path:, output_dir:, namespace: "Schema")
        @api_spec = T.let(Psych.load_file(api_spec_path), T::Hash[String, T.untyped])

        @output_dir = T.let(output_dir.is_a?(String) ? Pathname(output_dir) : output_dir, Pathname)
        @namespace = T.let(namespace, String)
      end

      sig { void }
      def generate_all!
        @api_spec.dig("components", "schemas").each do |name, schema|
          generate_schema(schema, @namespace, name.to_s)
        end
      end

      sig { params(schema_name: String).void }
      def generate!(schema_name)
        name = schema_name.camelize

        schema = @api_spec.dig("components", "schemas", name)

        raise OpenapiSorbetRails::SchemaNotFoundError, schema_name if schema.nil?

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

      sig {
        params(
          schema: T::Hash[String, T.untyped],
          namespace: String,
          name: String,
          create_primitive: T::Boolean,
        ).returns(String)
      }
      def generate_schema(schema, namespace, name, create_primitive: true)
        spec_doc = Psych.dump(schema, header: false, indentation: 2)
        class_name = "#{namespace}::#{name}"

        case schema.transform_keys(&:to_sym)
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
          property_types = schema["properties"].to_h { |property_name, property_schema|
            [
              property_name,
              generate_schema(property_schema, class_name, property_name.camelize, create_primitive: false)
                .tap { break "T.nilable(#{_1})" unless schema["required"].to_a.include?(property_name.to_s) }
            ]
          }

          create_object_class_file(class_name, property_types, spec_doc)
        in { oneOf: child_schemas }
          type = child_schemas.map.with_index(1) { |child_schema, index|
            generate_schema(child_schema, class_name, "OneOf#{index}", create_primitive: false)
          }.then { "T.any(#{_1.join(", ")})" }

          create_oneof_class_file(class_name, type, spec_doc)
        in { allOf: child_schemas }
          child_types = child_schemas.map.with_index(1) { |child_schema, index|
            [
              "all_of#{index}",
              generate_schema(child_schema, class_name, "AllOf#{index}")
            ]
          }.to_h

          create_allof_class_file(class_name, child_types, spec_doc)
        in { type: "array" }
          return "T::Array[#{generate_schema(schema["items"], class_name, "Item", create_primitive: false)}]"
        in { "$ref": schema_ref }
          return "#{@namespace}::#{schema_ref.split("/").last}"
        else
          raise OpenapiSorbetRails::UnsupportedSchemaError, schema
        end

        class_name
      end

      sig { params(class_name: String, type: String, spec_doc: String).void }
      def create_primitive_class_file(class_name, type, spec_doc)
        file_content = ERB.new(File.read(template_path("primitive")), trim_mode: "-").result(binding)

        write_class_file(class_name, file_content)
      end

      sig { params(class_name: String, property_types: T::Hash[Symbol, String], spec_doc: String).void }
      def create_object_class_file(class_name, property_types, spec_doc)
        file_content = ERB.new(File.read(template_path("object")), trim_mode: "-").result(binding)

        write_class_file(class_name, file_content)
      end

      sig { params(class_name: String, type: String, spec_doc: String).void}
      def create_oneof_class_file(class_name, type, spec_doc)
        file_content = ERB.new(File.read(template_path("oneof")), trim_mode: "-").result(binding)

        write_class_file(class_name, file_content)
      end

      sig { params(class_name: String, properties: T::Hash[Symbol, String], spec_doc: String).void}
      def create_allof_class_file(class_name, properties, spec_doc)
        file_content = ERB.new(File.read(template_path("allof")), trim_mode: "-").result(binding)

        write_class_file(class_name, file_content)
      end

      sig { params(class_name: String, file_content: String).void }
      def write_class_file(class_name, file_content)
        file_path = @output_dir.join("#{class_name.underscore}.rb")

        FileUtils.mkdir_p(file_path.dirname)
        File.write(file_path, file_content)

        warn "Generated: #{class_name} => #{file_path}"
      end

      sig { params(name: String).returns(Pathname) }
      def template_path(name)
        Pathname.new(__dir__).join("templates/schema/#{name}.rb.erb")
      end
    end
  end
end
