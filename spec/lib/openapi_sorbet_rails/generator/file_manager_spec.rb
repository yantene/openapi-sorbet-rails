# frozen_string_literal: true
# typed: false

require "spec_helper"
require "tmpdir"
require "prism"
require "zeitwerk"

require "openapi_sorbet_rails/generator/file_manager"

require "psych"
require "active_support/all"

RSpec.describe OpenapiSorbetRails::Generator::FileManager do
  around(:example) do |example|
    Dir.mktmpdir do |dir|
      @dir = Pathname.new(dir)

      @loader = Zeitwerk::Loader.new
      @loader.push_dir(@dir)
      @loader.enable_reloading
      @loader.setup

      example.run

      @loader.unload
    end
  end

  describe "#initialize" do
  end

  describe "#clean_up!" do
  end

  describe "#create_empty_module_file" do
    it "creates a file with the correct name" do
      described_class.new(output_dir: @dir).create_empty_module_file("Fizz::Buzz::EmptyModuleFoo")

      expect(@dir.join("fizz/buzz/empty_module_foo.rb")).to be_file
    end

    it "creates a file with the correct module name" do
      described_class.new(output_dir: @dir).create_empty_module_file("Fizz::Buzz::EmptyModuleFoo")

      ast = Prism.parse_file(@dir.join("fizz/buzz/empty_module_foo.rb").to_s)
      node = ast.value.statements.body[0]

      expect(node.constant_path.child.name).to eq(:EmptyModuleFoo)
      expect(node.constant_path.parent.child.name).to eq(:Buzz)
      expect(node.constant_path.parent.parent.name).to eq(:Fizz)
    end
  end

  describe "#create_primitive_class_file" do
    it "creates a file with the correct name" do
      described_class.new(output_dir: @dir)
        .create_primitive_class_file("Fizz::Buzz::PrimitiveClassFoo", "String", "spec_doc")

      expect(@dir.join("fizz/buzz/primitive_class_foo.rb")).to be_file
    end

    it "creates a file with the correct class name" do
      described_class.new(output_dir: @dir)
        .create_primitive_class_file("Fizz::Buzz::PrimitiveClassFoo", "String", "spec_doc")

      ast = Prism.parse_file(@dir.join("fizz/buzz/primitive_class_foo.rb").to_s)
      node = ast.value.statements.body[0]

      expect(node.constant_path.child.name).to eq(:PrimitiveClassFoo)
      expect(node.constant_path.parent.child.name).to eq(:Buzz)
      expect(node.constant_path.parent.parent.name).to eq(:Fizz)
    end
  end

  describe "#create_object_class_file" do
    it "creates a file with the correct name" do
      described_class.new(output_dir: @dir)
        .create_object_class_file(
          "Fizz::Buzz::ObjectClassFoo",
          {hoge: {type: "String"}},
          "spec_doc"
        )

      expect(@dir.join("fizz/buzz/object_class_foo.rb")).to be_file
    end

    it "creates a file with the correct class name" do
      described_class.new(output_dir: @dir)
        .create_object_class_file(
          "Fizz::Buzz::ObjectClassFoo",
          {hoge: {type: "String"}},
          "spec_doc"
        )

      ast = Prism.parse_file(@dir.join("fizz/buzz/object_class_foo.rb").to_s)
      node = ast.value.statements.body[0]

      expect(node.constant_path.child.name).to eq(:ObjectClassFoo)
      expect(node.constant_path.parent.child.name).to eq(:Buzz)
      expect(node.constant_path.parent.parent.name).to eq(:Fizz)
    end
  end

  describe "#create_oneof_class_file" do
    it "creates a file with the correct name" do
      described_class.new(output_dir: @dir)
        .create_oneof_class_file(
          "Fizz::Buzz::OneofClassFoo",
          "T.any(String, Integer)",
          "spec_doc"
        )

      expect(@dir.join("fizz/buzz/oneof_class_foo.rb")).to be_file
    end

    it "creates a file with the correct class name" do
      described_class.new(output_dir: @dir)
        .create_oneof_class_file(
          "Fizz::Buzz::OneofClassFoo",
          "T.any(String, Integer)",
          "spec_doc"
        )

      ast = Prism.parse_file(@dir.join("fizz/buzz/oneof_class_foo.rb").to_s)
      node = ast.value.statements.body[0]

      expect(node.constant_path.child.name).to eq(:OneofClassFoo)
      expect(node.constant_path.parent.child.name).to eq(:Buzz)
      expect(node.constant_path.parent.parent.name).to eq(:Fizz)
    end
  end

  describe "#create_allof_class_file" do
    it "creates a file with the correct name" do
      described_class.new(output_dir: @dir)
        .create_allof_class_file(
          "Fizz::Buzz::AllofClassFoo",
          {hoge: "String", fuga: "Integer"},
          "spec_doc"
        )

      expect(@dir.join("fizz/buzz/allof_class_foo.rb")).to be_file
    end

    it "creates a file with the correct class name" do
      described_class.new(output_dir: @dir)
        .create_allof_class_file(
          "Fizz::Buzz::AllofClassFoo",
          {hoge: "String", fuga: "Integer"},
          "spec_doc"
        )

      ast = Prism.parse_file(@dir.join("fizz/buzz/allof_class_foo.rb").to_s)
      node = ast.value.statements.body[0]

      expect(node.constant_path.child.name).to eq(:AllofClassFoo)
      expect(node.constant_path.parent.child.name).to eq(:Buzz)
      expect(node.constant_path.parent.parent.name).to eq(:Fizz)
    end
  end
end
