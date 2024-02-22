# typed: strict

# 以下を解決する rbi ファイルを書く
# Method `deep_stringify_keys` does not exist on `T::Hash[Symbol, T.untyped]`

class Hash
  sig { returns(T::Hash[String, T.untyped]) }
  def deep_stringify_keys
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def deep_symbolize_keys
  end
end


