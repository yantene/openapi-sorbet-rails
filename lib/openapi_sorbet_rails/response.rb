# typed: strict

module OpenapiSorbetRails
  module Response
    extend T::Sig
    extend T::Helpers

    interface!

    sig { abstract.returns(T::Hash[Symbol, T.untyped]) }
    def as_json
    end

    sig { abstract.returns(String) }
    def status
    end
  end
end
