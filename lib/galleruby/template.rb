require 'set'
require 'haml'

module Galleruby
  class Template
      @@cache = {}

      def initialize(file, config, output_filename=nil, base_directory=nil)
          @config = config

          file = template_path file
          if not @@cache.has_key? file then
              @@cache[file] = Haml::Engine.new(File.read(file))
          end

          @engine = @@cache[file]
          @locals = {}
          @output_filename = output_filename
          @base_directory = base_directory
      end

      def template_path(name)
          "#{@config[:templates]}/#{name}.haml"
      end

      def render_to(filename, locals={}, base=nil)
          @output_filename = filename
          @base_directory = base

          content = render(locals)
          File.open(filename, 'w') do |file|
              file.write(content)
          end

          @base_directory = nil
          @output_filename = nil
      end

      def render(locals={})
          if @output_filename.nil?
              @output_filename = ''
          end

          @locals = locals
          @locals[:config] = @config

          @engine.render(self, @locals)
      end

      def include_for_each(file, elements)
          elements.map { |element|
              include_template(file, element)
          }.join("\n")
      end

      def include_template(file, locals={})
          template = self.class.new(file, @config, @output_filename, @base_directory)
          template.render(@locals.merge(locals))
      end

      def base_relative(path)
          return path if @output_filename.nil? or @base_directory.nil?
          components = File.dirname(@output_filename).split '/'
          if components.first != @base_directory
              components = [".."] * components.length + [@base_directory]
          else
              components = [".."] * (components.length - 1)
          end
          components << path

          return components.join('/')
      end
  end

  class TemplatePlaceholder
      def method_missing(m, *args, &block)
          TemplatePlaceholder.new
      end
  end

  class TemplateDependencyCalculator < Template
      attr_accessor :files

      def initialize(file, config, output_filename=nil, base_directory=nil)
          super(file, config, output_filename, base_directory)
          @file = file
          render_to('/dev/null')
      end

      def render(locals={})
          @files = Set[@file]
          @engine.render(self)
      end

      def include_for_each(file, elements)
          include_template file
      end

      def include_template(file, locals={})
          template = self.class.new(file, @config, @output_filename, @base_directory)
          (@files << file).merge(template.files)
      end

      def method_missing(m, *args, &block)
          TemplatePlaceholder.new
      end
  end
end
