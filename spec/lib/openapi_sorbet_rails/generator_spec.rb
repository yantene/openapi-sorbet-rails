# frozen_string_literal: true
# typed: false

require "spec_helper"
require "tmpdir"
require "prism"
require "zeitwerk"

require "openapi_sorbet_rails/generator"

require "psych"
require "active_support/all"

RSpec.describe OpenapiSorbetRails::Generator do
  describe "#generate_all!"

  describe "#generate_schema!"

  describe "#clean_up!"
end
