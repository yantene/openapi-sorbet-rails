# frozen_string_literal: true
# typed: strict

module OpenapiSorbetRails
  class Generator
    class ComponentGenerator
      extend T::Sig

      sig {
        params(
          api_spec: T::Hash[Symbol, T.untyped],
          output_dir: T.any(String, Pathname),
          namespace_prefix: T.nilable(String)
        ).void
      }
      def initialize(api_spec:, output_dir:, namespace_prefix: nil)
        @api_spec = api_spec
        @namespace_prefix = namespace_prefix

        @schema_generator = T.let(
          OpenapiSorbetRails::Generator::SchemaGenerator.new(output_dir:, namespace_prefix:),
          OpenapiSorbetRails::Generator::SchemaGenerator
        )
      end

      sig { void }
      def generate_all!
        generate_all_responses!
        generate_all_schemas!
      end

      sig { void }
      def generate_all_responses!
        @schema_generator.dig_namespace(namespace: [@namespace_prefix, "Components::Responses"].compact.join("::"))

        @api_spec.dig(:components, :responses)&.each do |name, value|
          generate_response!(name:) if value.dig(:content, :"application/json")
        end
      end

      sig { void }
      def generate_all_schemas!
        @schema_generator.dig_namespace(namespace: [@namespace_prefix, "Components::Schemas"].compact.join("::"))

        @api_spec.dig(:components, :schemas)&.each_key do |name|
          generate_schema!(name:)
        end
      end

      sig { params(name: Symbol).returns(String) }
      def generate_response!(name:)
        @schema_generator.dig_namespace(namespace: [@namespace_prefix, "Components::Responses"].compact.join("::"))

        @schema_generator.generate(
          name:,
          schema: @api_spec.dig(:components, :responses, name, :content, :"application/json", :schema),
          namespace: [@namespace_prefix, "Components::Responses"].compact.join("::")
        )
      end

      sig { params(name: Symbol).returns(String) }
      def generate_schema!(name:)
        @schema_generator.dig_namespace(namespace: [@namespace_prefix, "Components::Schemas"].compact.join("::"))

        @schema_generator.generate(
          name:,
          schema: @api_spec.dig(:components, :schemas, name),
          namespace: [@namespace_prefix, "Components::Schemas"].compact.join("::")
        )
      end
    end
  end
end
