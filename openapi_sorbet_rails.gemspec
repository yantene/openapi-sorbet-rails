# frozen_string_literal: true

require_relative "lib/openapi_sorbet_rails/version"

Gem::Specification.new do |spec|
  spec.name = "openapi_sorbet_rails"
  spec.version = OpenapiSorbetRails::VERSION
  spec.authors = ["Shuhei YOSHIDA"]
  spec.email = ["contact@yantene.net"]

  spec.summary = "Generate Ruby objects with Sorbet types from OpenAPI 3.1 for Rails."
  spec.description = "Generates Ruby objects with Sorbet types from OpenAPI 3.1 for Rails."
  spec.homepage = "https://github.com/yantene/openapi-sorbet-rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/yantene/openapi-sorbet-rails/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["openapi_sorbet_rails"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_dependency "sorbet-runtime"
  spec.add_dependency "thor"
end
