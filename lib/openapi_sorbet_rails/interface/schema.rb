# frozen_string_literal: true
# typed: strict

module OpenapiSorbetRails
  module Interface
    module Component
      extend T::Sig
      extend T::Helpers

      interface!

      sig do
        abstract.returns(
          T.any(
            Float,
            Integer,
            String,
            T::Boolean,
            NilClass,
            T::Hash[Symbol, T.untyped],
            T::Array[T.untyped]
          )
        )
      end
      def as_json
      end
    end
  end
end
