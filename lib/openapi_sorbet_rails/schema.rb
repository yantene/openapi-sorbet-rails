# typed: strict

module OpenapiSorbetRails
  module Schema
    extend T::Sig
    extend T::Helpers

    interface!

    sig {
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
    }
    def as_json
    end
  end
end
