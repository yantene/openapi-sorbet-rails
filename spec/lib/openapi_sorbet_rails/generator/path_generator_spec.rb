# frozen_string_literal: true
# typed: false

require "spec_helper"
require "tmpdir"
require "zeitwerk"

require "openapi_sorbet_rails/generator/path_generator"

require "psych"
require "active_support/all"

RSpec.describe OpenapiSorbetRails::Generator::PathGenerator do
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

  describe "#generate_all!" do
    subject(:generate_all!) do
      described_class.new(api_spec:, output_dir: @dir, namespace_prefix: "Api").generate_all!
    end

    context "when a response body is defined inline" do
      let(:api_spec) do
        Psych.safe_load(<<~YAML).deep_symbolize_keys
          paths:
            "/health":
              get:
                responses:
                  "200":
                    description: OK
                    content:
                      application/json:
                        schema:
                          type: object
                          required:
                            - status
                          properties:
                            status:
                              type: string
        YAML
      end

      it "generates a struct named after the path, verb and status code" do
        generate_all!
        @loader.reload

        response = Api::Paths::Health::Get::Responses::Status200.new(status: "ok")

        expect(response.as_json).to eq({status: "ok"})
      end
    end

    context "when a response body is a $ref" do
      let(:api_spec) do
        Psych.safe_load(<<~YAML).deep_symbolize_keys
          paths:
            "/posts/{postId}":
              parameters:
                - name: postId
                  in: path
                  required: true
                  schema:
                    type: string
              get:
                responses:
                  "200":
                    description: A single post
                    content:
                      application/json:
                        schema:
                          "$ref": "#/components/schemas/Post"
        YAML
      end

      it "aliases the referenced component, turning the path template into a namespace" do
        generate_all!

        file = @dir.join("api/paths/posts/post_id/get/responses/status200.rb")

        expect(file).to be_file
        expect(file.read).to include("Status200 = T.type_alias { Api::Components::Schemas::Post }")
      end

      it "does not mistake parameters for an operation" do
        generate_all!

        expect(@dir.join("api/paths/posts/post_id/parameters")).not_to exist
        expect(@dir.join("api/paths/posts/post_id/parameters.rb")).not_to exist
      end
    end

    context "when a response body is an array" do
      let(:api_spec) do
        Psych.safe_load(<<~YAML).deep_symbolize_keys
          paths:
            "/posts":
              get:
                responses:
                  "200":
                    description: A list of posts
                    content:
                      application/json:
                        schema:
                          type: array
                          items:
                            "$ref": "#/components/schemas/Post"
        YAML
      end

      it "aliases the array type" do
        generate_all!

        file = @dir.join("api/paths/posts/get/responses/status200.rb")

        expect(file).to be_file
        expect(file.read).to include("Status200 = T.type_alias { T::Array[Api::Components::Schemas::Post] }")
      end
    end

    context "when a response carries no application/json body" do
      let(:api_spec) do
        Psych.safe_load(<<~YAML).deep_symbolize_keys
          paths:
            "/posts/{postId}":
              delete:
                responses:
                  "204":
                    description: No Content
        YAML
      end

      it "generates nothing for it" do
        generate_all!

        expect(@dir.join("api/paths/posts/post_id/delete")).not_to exist
      end
    end

    context "when the document has no paths" do
      let(:api_spec) do
        Psych.safe_load(<<~YAML).deep_symbolize_keys
          components:
            schemas:
              Post:
                type: object
        YAML
      end

      it "does not raise" do
        expect { generate_all! }.not_to raise_error
      end
    end
  end
end
