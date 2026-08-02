# frozen_string_literal: true
# typed: strict

module OpenapiSorbetRails
  class Generator
    class PathGenerator
      extend T::Sig

      # Keys of a Path Item Object that describe an operation. Every other key
      # (`parameters`, `summary`, `servers`, ...) describes the path itself.
      HTTP_VERBS = T.let(
        %i[get put post delete options head patch trace].freeze,
        T::Array[Symbol]
      )

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
      end

      sig { void }
      def generate_all_responses!
        each_json_response do |path, verb, status_code, _schema|
          generate_response!(path:, verb:, status_code:)
        end
      end

      sig { params(path: Symbol, verb: Symbol, status_code: Symbol).returns(String) }
      def generate_response!(path:, verb:, status_code:)
        namespace = response_namespace(path:, verb:)
        @schema_generator.dig_namespace(namespace:)

        schema = response_schema(path:, verb:, status_code:)
        class_name = "#{namespace}::Status#{status_code}"

        type = @schema_generator.generate(
          name: :"Status#{status_code}",
          schema:,
          namespace:
        )

        # A $ref or an array resolves to a type that already lives elsewhere, so
        # no class was written for it. Alias it so the response can be referred
        # to by its position in the document.
        @schema_generator.create_type_alias(class_name:, type:, schema:) if type != class_name

        type
      end

      private

      # Yields every response that carries an application/json body, skipping
      # non-operation keys of a Path Item Object and bodiless responses such as 204.
      sig {
        params(
          block: T.proc.params(
            path: Symbol,
            verb: Symbol,
            status_code: Symbol,
            schema: T::Hash[Symbol, T.untyped]
          ).void
        ).void
      }
      def each_json_response(&block)
        @api_spec[:paths]&.each do |path, path_item|
          path_item.each do |verb, operation|
            next unless HTTP_VERBS.include?(verb)

            operation[:responses]&.each do |status_code, response|
              schema = response.dig(:content, :"application/json", :schema)
              next if schema.nil?

              block.call(path, verb, status_code, schema)
            end
          end
        end
      end

      sig { params(path: Symbol, verb: Symbol, status_code: Symbol).returns(T::Hash[Symbol, T.untyped]) }
      def response_schema(path:, verb:, status_code:)
        @api_spec.dig(:paths, path, verb, :responses, status_code, :content, :"application/json", :schema)
      end

      sig { params(path: Symbol, verb: Symbol).returns(String) }
      def response_namespace(path:, verb:)
        [
          @namespace_prefix,
          "Paths",
          path_namespace(path),
          verb.to_s.camelize,
          "Responses"
        ].compact.join("::")
      end

      # "/posts/{postId}" => "Posts::PostId"
      sig { params(path: Symbol).returns(String) }
      def path_namespace(path)
        path.to_s.split("/").reject(&:empty?).map do |segment|
          segment.delete_prefix("{").delete_suffix("}").underscore.camelize
        end.join("::")
      end
    end
  end
end
