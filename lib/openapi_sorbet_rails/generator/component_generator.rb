# frozen_string_literal: true
# typed: strict

module OpenapiSorbetRails
  class Generator
    class ComponentGenerator
      extend T::Sig

      sig do
        params(
          api_spec: T::Hash[Symbol, T.untyped],
          output_dir: T.any(String, Pathname),
          namespace_prefix: T.nilable(String)
        ).void
      end
      def initialize(api_spec:, output_dir:, namespace_prefix: nil)
        @api_spec = api_spec

        @file_manager = T.let(
          OpenapiSorbetRails::Generator::FileManager.new(
            output_dir: output_dir.is_a?(Pathname) ? output_dir : Pathname.new(output_dir)
          ),
          OpenapiSorbetRails::Generator::FileManager
        )
        @namespace_prefix = namespace_prefix
      end

      sig { void }
      def generate_all!
        generate_all_responses!
        generate_all_schemas!
      end

      sig { void }
      def generate_all_responses!
        dig_namespace(namespace: [@namespace_prefix, "Components::Responses"].compact.join("::"))

        @api_spec.dig(:components, :responses)&.each do |name, value|
          generate_response!(name:) if value.dig(:content, :"application/json")
        end
      end

      sig { void }
      def generate_all_schemas!
        dig_namespace(namespace: [@namespace_prefix, "Components::Schemas"].compact.join("::"))

        @api_spec.dig(:components, :schemas)&.each_key do |name|
          generate_schema!(name:)
        end
      end

      sig { params(name: Symbol).returns(String) }
      def generate_response!(name:)
        dig_namespace(namespace: [@namespace_prefix, "Components::Responses"].compact.join("::"))

        generate(
          name:,
          schema: @api_spec.dig(:components, :responses, name, :content, :"application/json", :schema),
          namespace: [@namespace_prefix, "Components::Responses"].compact.join("::")
        )
      end

      sig { params(name: Symbol).returns(String) }
      def generate_schema!(name:)
        dig_namespace(namespace: [@namespace_prefix, "Components::Schemas"].compact.join("::"))

        generate(
          name:,
          schema: @api_spec.dig(:components, :schemas, name),
          namespace: [@namespace_prefix, "Components::Schemas"].compact.join("::")
        )
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

      sig do
        params(
          name: Symbol,
          schema: T::Hash[Symbol, T.untyped],
          namespace: T.nilable(String),
          create_primitive: T::Boolean
        ).returns(String)
      end
      def generate(name:, schema:, namespace:, create_primitive: true)
        spec_doc = Psych.dump(schema.deep_stringify_keys, header: false, indentation: 2)
        class_name = [namespace, name].compact.join("::")

        case schema
        in { type: "number" }
          return "Float" unless create_primitive

          @file_manager.create_primitive_class_file(class_name, "Float", spec_doc)
        in { type: "integer" }
          return "Integer" unless create_primitive

          @file_manager.create_primitive_class_file(class_name, "Integer", spec_doc)
        in { type: "string" }
          return "String" unless create_primitive

          @file_manager.create_primitive_class_file(class_name, "String", spec_doc)
        in { type: "boolean" }
          return "T::Boolean" unless create_primitive

          @file_manager.create_primitive_class_file(class_name, "T::Boolean", spec_doc)
        in { type: "null" }
          return "NilClass" unless create_primitive

          @file_manager.create_primitive_class_file(class_name, "NilClass", spec_doc)
        in { type: "object" }
          property_types = schema[:properties].to_h do |property_name, property_schema|
            type = generate(name: property_name.to_s.camelize.to_sym, schema: property_schema, namespace: class_name, create_primitive: false)

            [
              property_name,
              {
                type: type.tap { break "T.nilable(#{_1})" unless schema[:required].to_a.include?(property_name.to_s) },
                primitive: ["Float", "Integer", "String", "T::Boolean", "NilClass"].include?(type)
              }
            ]
          end

          @file_manager.create_object_class_file(class_name, property_types, spec_doc)
        in { oneOf: child_schemas }
          type = child_schemas.map.with_index(1) do |child_schema, index|
            generate(name: :"OneOf#{index}", schema: child_schema, namespace: class_name, create_primitive: false)
          end.then { "T.any(#{_1.join(", ")})" }

          @file_manager.create_oneof_class_file(class_name, type, spec_doc)
        in { allOf: child_schemas }
          child_types = child_schemas.map.with_index(1) do |child_schema, index|
            [
              "all_of#{index}",
              generate(name: :"AllOf#{index}", schema: child_schema, namespace: class_name)
            ]
          end.to_h

          @file_manager.create_allof_class_file(class_name, child_types, spec_doc)
        in { type: "array" }
          item_type = generate(name: :Item, schema: schema[:items], namespace: class_name, create_primitive: false)

          # Create empty module file for item type unless it's a primitive type or $ref
          @file_manager.create_empty_module_file(class_name) if item_type == "#{class_name}::Item"

          return "T::Array[#{item_type}]"
        in { "$ref": schema_ref }
          return "#{@namespace_prefix}::#{schema_ref.delete_prefix("#/").split("/").map(&:camelize).join("::")}"
        else
          raise OpenapiSorbetRails::UnsupportedSchemaError, schema
        end

        class_name
      end
    end
  end
end
