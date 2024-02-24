# frozen_string_literal: true
# typed: false

require "spec_helper"
require "tmpdir"
require "prism"
require "zeitwerk"

require "openapi_sorbet_rails/generator/schema_generator"

require "psych"
require "active_support/all"

RSpec.describe OpenapiSorbetRails::Generator::SchemaGenerator do
  describe "#generate!" do
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

    context "when type is primitive" do
      context "when schema is a simple primitive" do
        let(:schema) do
          Psych.safe_load(<<~YAML).deep_symbolize_keys
            components:
              schemas:
                SimpleInteger:
                  type: integer
                SimpleNumber:
                  type: number
                SimpleString:
                  type: string
                SimpleBoolean:
                  type: boolean
                SimpleNull:
                  type: "null"
          YAML
        end

        it "generates a class that returns the correct JSON" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          {
            SimpleInteger: 1,
            SimpleNumber: 1.5,
            SimpleString: "fizzbuzz",
            SimpleBoolean: true,
            SimpleNull: nil
          }.each do |class_name, value|
            simple_primitive = Fizz::Buzz::Schema.const_get(class_name).new(value:)

            expect(simple_primitive.as_json).to eq(value)
          end
        end

        it "generates a class that raises an error when the value is not one of the types" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          {
            SimpleInteger: 1.5,
            SimpleNumber: "fizzbuzz",
            SimpleString: true,
            SimpleBoolean: nil,
            SimpleNull: 1
          }.each do |class_name, value|
            expect { Fizz::Buzz::Schema.const_get(class_name).new(value:) }.to raise_error(TypeError)
          end
        end
      end
    end

    context "when type is object" do
      context "when schema is a flat object" do
        let(:schema) do
          Psych.safe_load(<<~YAML).deep_symbolize_keys
            components:
              schemas:
                FlatObject:
                  type: object
                  properties:
                    int:
                      type: integer
                    str:
                      type: string
                    nul:
                      type: "null"
                    nullableInt:
                      type: integer
                  required:
                    - int
                    - str
                    - nul
          YAML
        end

        it "generates a class that returns the correct JSON" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          flat_object = Fizz::Buzz::Schema::FlatObject.new(
            int: 1,
            str: "fizzbuzz",
            nul: nil,
            nullable_int: nil
          )

          expect(flat_object.as_json).to eq(
            int: 1,
            str: "fizzbuzz",
            nul: nil,
            nullableInt: nil
          )
        end

        it "generates a class that raises an error when the value is not one of the types" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          expect do
            Fizz::Buzz::Schema::FlatObject.new(
              int: "fizzbuzz",
              str: nil,
              nul: nil,
              nullable_int: 1
            )
          end.to raise_error(TypeError)
        end
      end

      xcontext "when schema is a nested object" do
      end
    end

    context "when type is oneOf" do
      context "when schema is a flat one of" do
        let :schema do
          Psych.safe_load(<<~YAML).deep_symbolize_keys
            components:
              schemas:
                FlatOneOf:
                  oneOf:
                    - type: integer
                    - type: string
          YAML
        end

        it "generates a class that returns the correct JSON" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          expect(Fizz::Buzz::Schema::FlatOneOf.new(value: 1).as_json).to eq(1)
          expect(Fizz::Buzz::Schema::FlatOneOf.new(value: "one").as_json).to eq("one")
        end

        it "generates a class that raises an error when the value is not one of the types" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          expect do
            Fizz::Buzz::Schema::FlatOneOf.new(value: 1.5)
          end.to raise_error(TypeError)
        end
      end
    end

    context "when type is allOf" do
      context "when schema is an object all of" do
        let :schema do
          Psych.safe_load(<<~YAML).deep_symbolize_keys
            components:
              schemas:
                ObjectAllOf:
                  allOf:
                    - type: object
                      properties:
                        foo:
                          type: integer
                    - type: object
                      properties:
                        bar:
                          type: string
          YAML
        end

        it "generates a class that returns the correct JSON" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          expect(
            Fizz::Buzz::Schema::ObjectAllOf.new(
              all_of1: Fizz::Buzz::Schema::ObjectAllOf::AllOf1.new(foo: 1),
              all_of2: Fizz::Buzz::Schema::ObjectAllOf::AllOf2.new(bar: "one")
            ).as_json
          ).to eq(
            foo: 1,
            bar: "one"
          )
        end

        it "generates a class that raises an error when the value is not one of the types" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          expect do
            Fizz::Buzz::Schema::ObjectAllOf.new(
              all_of1: Fizz::Buzz::Schema::ObjectAllOf::AllOf1.new(foo: "one"),
              all_of2: Fizz::Buzz::Schema::ObjectAllOf::AllOf2.new(bar: 1)
            )
          end.to raise_error(TypeError)
        end
      end
    end

    context "when type is array" do
      context "when schema is a primitive item array" do
        let :schema do
          Psych.safe_load(<<~YAML).deep_symbolize_keys
            components:
              schemas:
                FlatArray:
                  type: array
                  items:
                    type: integer
          YAML
        end

        it "generates no flat_array.rb file" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!

          expect(File).not_to exist(@dir.join("fizz/buzz/schema/flat_array.rb").to_s)
        end
      end

      context "when schema is an object item array" do
        let :schema do
          Psych.safe_load(<<~YAML).deep_symbolize_keys
            components:
              schemas:
                ObjectArray:
                  type: array
                  items:
                    type: object
                    properties:
                      foo:
                        type: integer
          YAML
        end

        it "generates a class file and a module file in the correct location" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          expect(File).to exist(@dir.join("fizz/buzz/schema/object_array.rb").to_s)
          expect(File).to exist(@dir.join("fizz/buzz/schema/object_array/item.rb").to_s)
        end

        it "generates a module with the correct name" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          ast = Prism.parse_file(@dir.join("fizz/buzz/schema/object_array.rb").to_s)

          module_node = ast.value.statements.body.find { _1.name == :ObjectArray }

          expect(module_node.constant_path.child.name).to eq :ObjectArray
          expect(module_node.constant_path.parent.child.name).to eq :Schema
          expect(module_node.constant_path.parent.parent.child.name).to eq :Buzz
          expect(module_node.constant_path.parent.parent.parent.name).to eq :Fizz
        end

        it "generates a class with the correct name" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          ast = Prism.parse_file(@dir.join("fizz/buzz/schema/object_array/item.rb").to_s)

          class_node = ast.value.statements.body.find { _1.name == :Item }

          expect(class_node.constant_path.child.name).to eq :Item
          expect(class_node.constant_path.parent.child.name).to eq :ObjectArray
          expect(class_node.constant_path.parent.parent.child.name).to eq :Schema
          expect(class_node.constant_path.parent.parent.parent.child.name).to eq :Buzz
          expect(class_node.constant_path.parent.parent.parent.parent.name).to eq :Fizz
        end
      end
    end

    context "when type is ref" do
      context "when schema is a reference" do
        let :schema do
          Psych.safe_load(<<~YAML).deep_symbolize_keys
            components:
              schemas:
                SimpleInteger:
                  type: integer
                RefObject:
                  type: object
                  properties:
                    simpleInteger:
                      $ref: "#/components/schemas/SimpleInteger"
          YAML
        end

        it "generates a class file in the correct location" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!

          expect(File).to exist(@dir.join("fizz/buzz/schema/ref_object.rb").to_s)
        end

        it "generates a class that returns the correct JSON" do
          described_class.new(api_spec: schema, output_dir: @dir, namespace: "Fizz::Buzz::Schema").generate_all!
          @loader.reload

          expect(
            Fizz::Buzz::Schema::RefObject.new(
              simple_integer: Fizz::Buzz::Schema::SimpleInteger.new(value: 1)
            ).as_json
          ).to eq({simpleInteger: 1})
        end
      end
    end
  end
end
