#!/usr/bin/env ruby
#
# == Synposis
#
# generate.rb: generates gallery from directories
#
# == Usage
#
# generate.rb [OPTION] ... DIR
#
# -h, --help:
#   show help
#
# -o <out>, --output <out>:
#   generates output gallery in <out> instead of the default output/
#
# -c <config>, --config <config>:
#   reads configuration options from <config> instead of config.yml
#
# -f, --force
#   forces regeneration of HTML files even if we think they album is unchanged.
#
# DIR: The directory to look for input albums in.

require 'ftools'
require 'yaml'
require 'getoptlong'
require 'rdoc/usage'

require 'rubygems'
require 'RMagick'
require 'haml'

EXIF_DATE_FORMAT = '%Y:%m:%d %H:%M:%S'
TRACK_ALLOCATIONS = false

# Class to easily instantiate an object when needed.
# Similar to using (object ||= Foo.new).bar, but stores the initialization code to make
# the code cleaner.
class LazyObject
    @object = nil
    def initialize(&code)
        @init = code
    end

    def was_initialized?
        not @object.nil?
    end

    def method_missing(m, *args, &block)
        if not was_initialized? then
            @object = @init.call
            @object.public_methods(false).each do |meth|
                (class << self; self; end).class_eval do
                    define_method meth do |*args|
                        @object.send meth, *args
                    end
                end
            end
            @object.send m, *args, &block
        else
            super.method_missing m, *args, &block
        end
    end
end

class Template
    @@cache = {}

    def initialize(file, output_filename=nil, base_directory=nil)
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
        "templates/#{name}.haml"
    end

    def render_to(filename, locals={}, base=nil)
        @output_filename = filename
        @base_directory = base

        File.open(filename, 'w') { |file|
            file.write(render(locals))
        }

        @base_directory = nil
        @output_filename = nil
    end

    def render(locals={})
        if @output_filename.nil?
            @output_filename = ''
        end

        @locals = locals
        @engine.render(self, locals)
    end

    def include_for_each(file, elements)
        elements.map { |element|
            include_template(file, element)
        }.join("\n")
    end

    def include_template(file, locals={})
        template = self.class.new(file, @output_filename, @base_directory)
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

    def initialize(file, output_filename=nil, base_directory=nil)
        super(file, output_filename, base_directory)
        @file = file
        render_to('/dev/null')
    end

    def render(locals={})
        @files = Set.new @file
        super(locals)
    end

    def include_for_each(file, elements)
        include_template file
    end

    def include_template(file, locals={})
        template = self.class.new(file, @output_filename, @base_directory)
        @files.add(file).merge(template.files)
    end

    def method_missing(m, *args, &block)
        TemplatePlaceholder.new
    end
end

class Album
    attr_reader :name

    # Album representing the passed in name in the passed in directory.
    def initialize(directory, name)
        @name = name
        @path = "#{directory}/#{name}"
        @settings_file = "#{@path}/.galleruby.yml"
        @skip_file = "#{@path}/.galleruby.skip"


        skiplist_file = "#{@skip_file}list"
        if File.exist? skiplist_file then
            @skiplist = YAML::load(File.read(skiplist_file))
        end
        @skiplist ||= []

        if valid? then
            @info = YAML::load(File.read(@settings_file))
        end

        @info ||= {}

        @images_by_date = nil
    end

    # Whether or not the input directory is considered a valid Galleruby album,
    # i.e. if it has the metadata-file, is not a 'hidden' directory and does not
    # have a blacklist (.galleruby.skip) file.
    def valid?
        return false if @name.start_with? '.'
        return false if not File.directory? @path
        return false if not File.exist? @settings_file
        return false if File.exist? @skip_file

        return true
    end

    # When the output HTML was last generated.
    def last_updated output_directory
        output_file = "#{output_directory}/#{@info['link']}/index.html"
        if File.exist? output_file then
            File.mtime output_file
        else
            Time.at(0)
        end
    end

    # Whether or not the album needs to update the generated HTML file and
    # possibly the resized images, based on when the input images were modified
    # and when the input HAML templates were last modified.
    def needs_updating?(output_directory, templates_modified)
        updated = last_updated output_directory

        # If the template is more recent, we need to update.
        return true if templates_modified > updated

        # If any of the images are more recent, we need to update.
        Dir.new(@path).each do |entry|
            next if not entry.match /\.jpe?g$/i
            return true if updated < File.mtime("#{@path}/#{entry}")
        end

        return false
    end

    # Whether or not the passed in filename needs to be generated from its
    # input, given when the input was last updated.
    def file_needs_updating?(output_filename, original_mtime)
        return true if not File.exist? output_filename
        return true if File.mtime(output_filename) < original_mtime

        return false
    end

    # Process generates any resized images for the album as needed, and also
    # generates metadata about the album that's cached in .galleruby.yml inside
    # the albums source directory
    def process(config, output_directory)
        to_process = []
        Dir.new(@path).each { |entry|
            next if not entry.match /\.jpe?g$/i
            next if @skiplist.include? entry

            to_process << entry
        }

        return false if to_process.empty?

        output_album = "#{output_directory}/#{@info['link']}"
        output_small = "#{output_album}/small"
        output_medium = "#{output_album}/medium"
        output_large = "#{output_album}/large"

        File.makedirs output_small, output_medium, output_large

        @images_by_date = Hash.new {|hash, key| hash[key] = [] }
        first_taken, last_taken = nil, nil

        # We go over each (loosely defined) valid image in the directory, and
        # generate any small, medium or large thumbnails needed. In addition, we
        # find the range of the EXIF DateTime header for the album, so that we
        # can store that as metadata for the album.
        to_process.each do |entry|
            filename = "#{@path}/#{entry}"
            small_filename = "#{output_small}/#{entry}"
            medium_filename = "#{output_medium}/#{entry}"
            large_filename = "#{output_large}/#{entry}"

            image = LazyObject.new { o = Magick::Image.read(filename).first; o.auto_orient!; o }
            original_mtime = File.mtime filename

            if file_needs_updating?(large_filename, original_mtime) then
                new_image = image.resize_to_fit(*config['large'])
                new_image.write(large_filename)
                image.destroy!

                image = new_image
            end

            if file_needs_updating?(medium_filename, original_mtime) then
                medium_image = image.resize_to_fit(*config['medium'])
                medium_image.write(medium_filename)
                medium_image.destroy!
            end

            if file_needs_updating?(small_filename, original_mtime) then
                small_image = image.resize_to_fit(*config['small'])
                small_image.write(small_filename)
            else
                small_image = Magick::Image.ping(small_filename).first
            end

            taken = small_image.get_exif_by_entry('DateTime').first[1]
            taken = Date.strptime(taken, EXIF_DATE_FORMAT)

            if last_taken.nil? then
                last_taken = taken
            else
                last_taken = taken if taken > last_taken
            end

            if first_taken.nil? then
                first_taken = taken
            else
                first_taken = taken if taken < first_taken
            end

            @images_by_date[taken.strftime] << {
                :taken => taken,
                :data => {
                    :filename => entry,
                    :thumb_width => small_image.columns,
                    :thumb_height => small_image.rows
                }
            }

            small_image.destroy!
            if not image.nil? and (image.is_a?(LazyObject) and image.was_initialized?) then
                image.destroy!
            end

            if TRACK_ALLOCATIONS and num_allocated > 0 then
                puts "#{name}: Num allocated: #{num_allocated}"
            end
        end

        @info['first'] = first_taken
        if first_taken.strftime == last_taken.strftime then
            @info['date'] = first_taken.strftime('%e. %b, %Y').lstrip
        else
            range_start = first_taken.strftime('%e').lstrip
            if first_taken.year == last_taken.year then
                if first_taken.month != last_taken.month then
                    range_start << first_taken.strftime('. %b')
                end
            else
                range_start << first_taken.strftime('. %b, %Y')
            end

            date_range = "#{range_start} - #{last_taken.strftime('%e. %b, %Y').lstrip}"
            @info['date'] = date_range
        end

        # Here we write out the original metadata + the EXIF date range we've
        # identified.
        File.open(@settings_file, 'w') { |file| file.write(YAML.dump(@info)) }

        return true
    end

    # Create a HTML-file for the album.
    def render_to(config, output_directory)
        images_by_date = @images_by_date.sort.map do |day, images|
            {
                :date => Date.strptime(day),
                :images => images.sort_by {|image| image[:taken]}.map {|image| image[:data]}
            }
        end

        output_file = "#{output_directory}/#{@info['link']}/index.html"
        Template.new('album').render_to(output_file, {:config => config, :title => @info['title'], :images_by_date => images_by_date}, output_directory)
    end

    # The year that the first photo was taken in.
    def year
        @info['first'].strftime('%Y')
    end

    # Data needed for generation of the index document.
    def template_info
        {:name => @info['title'], :link => @info['link'], :date => @info['date'], :first => @info['first']}
    end
end

def main
    opts = GetoptLong.new(
        [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
        [ '--output', '-o', GetoptLong::OPTIONAL_ARGUMENT ],
        [ '--config', '-c', GetoptLong::OPTIONAL_ARGUMENT ],
        [ '--force', '-f', GetoptLong::NO_ARGUMENT ]
    )

    output_directory = 'output'
    config_file = 'config.yml'
    force_regenerate = false
    opts.each do |opt, arg|
        case opt
        when '--help'
            RDoc::usage
        when '--output'
            output_directory = arg
        when '--config'
            config_file = arg
        when '--force'
            force_regenerate = true
        end
    end

    if ARGV.empty? then
        RDoc::usage
        return 1
    end

    directory = ARGV[0]

    # These are the default options
    config = {
        'title' => 'My Gallery',
        'small' => [320, 256],
        'medium' => [800, 600],
        'large' => [1280, 1024]
    }
    config.merge!(YAML::load(File.read(config_file)) || {})

    # If we TRACK_ALLOCATIONS, we keep a count of "currently allocated images", so
    # that we can identify memory leaks.
    num_allocated = 0
    if TRACK_ALLOCATIONS then
        Magick.trace_proc = Proc.new do |which, description, id, method|
            if which == :c then
                num_allocated += 1
            elsif which == :d then
                num_allocated -= 1
            else
                puts "#{which} #{id} #{description} (from #{method})"
            end
        end
    end

    # This dynamically generates a list of all the HAML templates referenced during
    # a render of album.haml, which we use to figure out if any of them have been
    # modified since last we generated.
    deps = TemplateDependencyCalculator.new('album')
    templates_modified = deps.files.collect { |file|
        path = deps.template_path(file)
        File.exist?(path) ? File.mtime(path) : Time.now
    }
    templates_modified = templates_modified.max

    # We iterate over each directory inside the directory passed on the commandline,
    # checking if any of them are considered valid albums (have .galleruby.yml etc,
    # see Album#valid?) and regenerate thumbnails & HTML if its needed.
    albums_by_year = Hash.new { |hash, key| hash[key] = [] }
    Dir.new(directory).each do |album|
        album = Album.new(directory, album)

        next if not album.valid?

        if force_regenerate or album.needs_updating?(output_directory, templates_modified)
            puts "#{album.name}: Processing album"
            if not album.process(config, output_directory) then
                puts "#{album.name}: WARNING! No images to process, skipping"
                next
            end

            puts "#{album.name}: Rendering HTML"
            album.render_to(config, output_directory)
        else
            puts "#{album.name}: No update needed, skipping"
        end

        albums_by_year[album.year] << album
    end

    puts "All done! Generating index."

    # Finally we generate the index unconditionally, since it's a really cheap
    # operation. It's possible that we should not do this unless neeed, so that
    # index.html's mtime will have some value.
    albums_by_year = albums_by_year.sort_by { |e| e[0] }.reverse.map {|year, albums| {:year => year, :albums => albums.map {|album| album.template_info }.sort_by {|album| album[:first]}.reverse } }
    Template.new('index').render_to("#{output_directory}/index.html", {:config => config, :albums_by_year => albums_by_year}, output_directory)

    return 0

if $0 == __FILE__ then
    exit main
end
