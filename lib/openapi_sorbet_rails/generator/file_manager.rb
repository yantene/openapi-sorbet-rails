# frozen_string_literal: true
# typed: strict

require_relative "../generator"

module OpenapiSorbetRails
  class Generator
    class FileManager
      extend T::Sig

      sig { params(output_dir: Pathname).void }
      def initialize(output_dir:)
        @output_dir = output_dir
      end

      sig { void }
      def clean_up!
        FileUtils.rm_rf(@output_dir)
      end

      sig { params(module_name: String).void }
      def create_empty_module_file(module_name)
        file_content = ERB.new(File.read(template_path("empty_module")), trim_mode: "-").result(binding)

        write_module_file(module_name, file_content)
      end

      sig { params(class_name: String, type: String, spec_doc: String).void }
      def create_primitive_class_file(class_name, type, spec_doc)
        file_content = ERB.new(File.read(template_path("primitive")), trim_mode: "-").result(binding)

        write_module_file(class_name, file_content)
      end

      sig { params(class_name: String, property_types: T::Hash[Symbol, String], spec_doc: String).void }
      def create_object_class_file(class_name, property_types, spec_doc)
        file_content = ERB.new(File.read(template_path("object")), trim_mode: "-").result(binding)

        write_module_file(class_name, file_content)
      end

      sig { params(class_name: String, type: String, spec_doc: String).void }
      def create_oneof_class_file(class_name, type, spec_doc)
        file_content = ERB.new(File.read(template_path("oneof")), trim_mode: "-").result(binding)

        write_module_file(class_name, file_content)
      end

      sig { params(class_name: String, properties: T::Hash[Symbol, String], spec_doc: String).void }
      def create_allof_class_file(class_name, properties, spec_doc)
        file_content = ERB.new(File.read(template_path("allof")), trim_mode: "-").result(binding)

        write_module_file(class_name, file_content)
      end

      private

      sig { params(module_name: String, file_content: String).void }
      def write_module_file(module_name, file_content)
        file_path = @output_dir.join("#{module_name.to_s.underscore}.rb")

        FileUtils.mkdir_p(file_path.dirname)
        File.write(file_path, file_content)

        warn "Generated: #{module_name} => #{file_path}"
      end

      sig { params(name: String).returns(Pathname) }
      def template_path(name)
        Pathname.new(__dir__).join("templates/#{name}.rb.erb")
      end
    end
  end
end
