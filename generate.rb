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
# DIR: The directory to look for input albums in.

require 'ftools'
require 'yaml'
require 'getoptlong'
require 'rdoc/usage'

require 'rubygems'
require 'RMagick'
require 'haml'

SMALL_SIZE = [320, 256]
MEDIUM_SIZE = [800, 600]
LARGE_SIZE = [1280, 1024]
EXIF_DATE_FORMAT = '%Y:%m:%d %H:%M:%S'
TRACK_ALLOCATIONS = false

class Template
    @@cache = {}

    def initialize(file, output_filename=nil, base_directory=nil)
        if not @@cache.has_key? file then
            @@cache[file] = Haml::Engine.new(File.read(file))
        end

        @engine = @@cache[file]
        @locals = {}
        @output_filename = output_filename
        @base_directory = base_directory
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
        template = Template.new("#{file}.haml", @output_filename, @base_directory)
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

        return components.join('/') + "/#{path}"
    end
end

opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--output', '-o', GetoptLong::OPTIONAL_ARGUMENT ]
)

output_directory = 'output'
opts.each do |opt, arg|
    case opt
    when '--help' 
        RDoc::usage
    when '--output'
        output_directory = arg
    end
end

if ARGV.empty? then
    RDoc::usage
    exit 1
end

directory = ARGV[0]

num_allocated = 0
if TRACK_ALLOCATIONS then
    Magick.trace_proc = Proc.new { |which, description, id, method|
        if which == :c then
            num_allocated += 1
            #puts "+ #{id} #{description} (from #{method})"
        elsif which == :d then
            num_allocated -= 1
            #puts "- #{id} #{description} (from #{method})"
        end
    }
end


class Album
    attr_reader :name

    def initialize(directory, name)
        @name = name
        @path = "#{directory}/#{name}"
        @settings_file = "#{@path}/.galleruby.yaml"
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

    def valid?
        return false if @name.start_with? '.'
        return false if not File.directory? @path
        return false if not File.exist? @settings_file
        return false if File.exist? @skip_file

        return true
    end

    def needs_updating? output_directory
        output_file = "#{output_directory}/#{@info['link']}/index.html"
        if File.exist? output_file then
            last_generated = File.mtime output_file

            needs_updating = false
            Dir.new(@path).each { |entry|
                next if not entry.match /\.jpe?g$/i

                if last_generated < File.mtime("#{@path}/#{entry}") then
                    return true
                end
            }

            return false
        end

        return true
    end

    def process(output_directory)
        to_process = []
        Dir.new(@path).each { |entry|
            next if not entry.match /\.jpe?g$/i
            next if @skiplist.include? entry

            to_process << entry
        }

        if to_process.empty?
            return false
        end

        output_album = "#{output_directory}/#{@info['link']}"
        output_small = "#{output_album}/small"
        output_medium = "#{output_album}/medium"
        output_large = "#{output_album}/large"

        File.makedirs output_small, output_medium, output_large

        @images_by_date = Hash.new {|hash, key| hash[key] = [] }
        first_taken, last_taken = nil, nil

        to_process.each do |entry|
            filename = "#{@path}/#{entry}"
            small_filename = "#{output_small}/#{entry}"
            medium_filename = "#{output_medium}/#{entry}"
            large_filename = "#{output_large}/#{entry}"

            image = Magick::Image.read(filename).first
            image.auto_orient!

            taken = image.get_exif_by_entry('DateTime').first[1]
            taken = Date.strptime(taken, EXIF_DATE_FORMAT)

            if not File.exist? large_filename then
                new_image = image.resize_to_fit(*LARGE_SIZE)
                new_image.write(large_filename)
                image.destroy!

                image = new_image
            end

            if not File.exist? medium_filename then
                medium_image = image.resize_to_fit(*MEDIUM_SIZE)
                medium_image.write(medium_filename)
                medium_image.destroy!
            end

            if not File.exist? small_filename then
                small_image = image.resize_to_fit(*SMALL_SIZE)
                small_image.write(small_filename)
            else
                small_image = Magick::Image.ping(small_filename).first
            end

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
                    :small_width => small_image.columns,
                    :small_height => small_image.rows
                }
            }

            small_image.destroy!
            image.destroy!

            if TRACK_ALLOCATIONS and num_allocated > 0 then
                puts "#{name}: Num allocated: #{num_allocated}"
            end
        end

        range_start = first_taken.strftime('%e')
        if first_taken.year == last_taken.year then
            if first_taken.month != last_taken.month then
                range_start << first_taken.strftime('. %b')
            end
        else
            range_start << first_taken.strftime('. %b, %Y')
        end

        date_range = "#{range_start} - #{last_taken.strftime('%e. %b, %Y')}"

        @info['first'] = first_taken
        @info['date'] = date_range

        File.open(@settings_file, 'w') { |file| file.write(YAML.dump(@info)) }

        return true
    end

    def render_to(output_directory)
        images_by_date = @images_by_date.sort.map do |day, images|
            {
                :date => Date.strptime(day),
                :images => images.sort_by {|image| image[:taken]}.map {|image| image[:data]}
            }
        end

        output_file = "#{output_directory}/#{@info['link']}/index.html"
        Template.new('album.haml').render_to(output_file, {:title => @info['title'], :images_by_date => images_by_date}, output_directory)
    end

    def year
        @info['first'].strftime('%Y')
    end

    def template_info
        {:name => @info['title'], :link => @info['link'], :date => @info['date'], :first => @info['first']}
    end
end

albums_by_year = Hash.new { |hash, key| hash[key] = [] }
Dir.new(directory).each do |album|
    album = Album.new(directory, album)

    next if not album.valid?

    if album.needs_updating? output_directory
        puts "#{album.name}: Processing album"
        if not album.process output_directory then
            puts "#{album.name}: WARNING! No images to process, skipping"
            next
        end

        puts "#{album.name}: Rendering HTML"
        album.render_to output_directory
    else
        puts "#{album.name}: No update needed, skipping"
    end

    albums_by_year[album.year] << album
end

puts "All done! Generating index."

years_content = []
index_template = Template.new 'index.per_year.haml'
albums_by_year = albums_by_year.sort_by { |e| e[0] }.reverse.map {|year, albums| {:year => year, :albums => albums.map {|album| album.template_info }.sort_by {|album| album[:first]}.reverse } }

Template.new('index.haml').render_to("output/index.html", {:title => "bilder.o7.no", :albums_by_year => albums_by_year}, output_directory)
