require 'opal/compiler'
require 'erb'

module Opal
  class Builder

    BUILDERS = { ".rb" => :build_ruby, ".js" => :build_js, ".erb" => :build_erb }

    def self.build(name)
      Builder.new.build name
    end

    def initialize(options = {})
      @paths = options.delete(:paths) || Opal.paths.clone
      @options = options
      @handled = {}
    end

    def append_path(path)
      @paths << path
    end

    def build(path)
      @segments = []

      require_asset path

      @segments.join
    end

    def build_str(str, options = {})
      @segments = []
      @segments << compile_ruby(str, options)
      @segments.join
    end

    def require_asset(path)
      location = find_asset path

      unless @handled[location]
        @handled[location] = true
        build_asset location
      end
    end

    def find_asset(path)
      path.untaint if path =~ /\A(\w[-.\w]*\/?)+\Z/
      file_types = %w[.rb .js .js.erb]

      @paths.each do |root|
        file_types.each do |type|
          test = File.join root, "#{path}#{type}"

          if File.exist? test
            return test
          end
        end
      end

      raise "Could not find asset: #{path}"
    end

    def build_asset(path)
      ext = File.extname path

      unless builder = BUILDERS[ext]
        raise "Unknown builder for #{ext}"
      end

      @segments << __send__(builder, path)
    end

    def compile_ruby(str, options = nil)
      options ||= @options.clone

      compiler = Compiler.new
      result = compiler.compile str, options

      compiler.requires.each do |r|
        require_asset r
      end

      result
    end

    def build_ruby(path)
      compile_ruby File.read(path), @options.clone
    end

    def build_js(path)
      File.read(path)
    end

    def build_erb(path)
      ::ERB.new(File.read(path)).result binding
    end

    module Util
      extend self

      # Used for uglifying source to minify
      def uglify(str)
        IO.popen('uglifyjs 2> /dev/null', 'r+') do |i|
          i.puts str
          i.close_write
          return i.read
        end
      rescue Errno::ENOENT
        $stderr.puts '"uglifyjs" command not found (install with: "npm install -g uglify-js")'
        nil
      end

      # Gzip code to check file size
      def gzip(str)
        IO.popen('gzip -f 2> /dev/null', 'r+') do |i|
          i.puts str
          i.close_write
          return i.read
        end
      rescue Errno::ENOENT
        $stderr.puts '"gzip" command not found, it is required to produce the .gz version'
        nil
      end
    end
  end
end
