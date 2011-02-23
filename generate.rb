#!/usr/bin/env ruby

require 'ftools'
require 'yaml'

require 'rubygems'
require 'RMagick'
require 'haml'

include Magick

SMALL_SIZE = [320, 256]
MEDIUM_SIZE = [800, 600]
LARGE_SIZE = [1280, 1024]
EXIF_DATE_FORMAT = '%Y:%m:%d %H:%M:%S'
ROOT = ''

class Template
    @@cache = {}

    def initialize(file)
        if not @@cache.has_key? file then
            @@cache[file] = Haml::Engine.new(File.read(file))
        end

        @engine = @@cache[file]
        @locals = {}
    end

    def render(locals={})
        @locals = locals
        @engine.render(self, locals)
    end

    def include_for_each(file, elements)
        elements.map{ |element|
            include_template(file, element)
        }.join("\n")
    end

    def include_template(file, locals={})
        Template.new("#{file}.haml").render(@locals.merge(locals))
    end
end


if ARGV.empty? then
    puts "Syntax: #{$0} <directory>"
    exit(1);
end

directory = ARGV[0]

num_allocated = 0
Magick.trace_proc = Proc.new { |which, description, id, method|
    if which == :c then
        num_allocated += 1
        #puts "+ #{id} #{description} (from #{method})"
    elsif which == :d then
        num_allocated -= 1
        #puts "- #{id} #{description} (from #{method})"
    else
        puts "Huh #{which.inspect}!"
    end
}

albums_by_year = Hash.new { |hash, key| hash[key] = [] }
Dir.new(directory).each { |album|
    path = "#{directory}/#{album}"
    settings_file = "#{path}/.galleruby.yaml"
    skip_file = "#{path}/.galleruby.skip"
    skiplist_file = "#{skip_file}list"

    next if not File.directory? path
    next if not File.exist? settings_file
    next if File.exist? skip_file

    puts "Examining #{album}."

    if File.exist? skiplist_file then
        skiplist = YAML::load(File.read(skiplist_file)) || []
    end
    skiplist = [] if skiplist.nil?

    info = YAML::load(File.read(settings_file))
    info = {} if info.nil?

    output_album = "output/#{info['link']}"
    output_small = "#{output_album}/small"
    output_medium = "#{output_album}/medium"
    output_large = "#{output_album}/large"
    output_html = "#{output_album}/index.html"

    album_dir = Dir.new(path)
    if File.exist? output_html then
        last_generated = File.mtime output_html

        needs_updating = false
        album_dir.each { |entry|
            next if not entry.match /\.(jpe?g|png)$/i

            if last_generated < File.mtime("#{path}/#{entry}") then
                needs_updating = true
                break
            end
        }

        if not needs_updating 
            albums_by_year[info['first'].strftime('%Y')] << {:name => info['title'], :link => info['link'], :date => info['date'], :first => info['first']}
            next
        end
    end

    File.makedirs output_small, output_medium, output_large

    total_images = 0
    images_by_date = Hash.new {|hash, key| hash[key] = [] }
    first_taken, last_taken = nil, nil
    album_dir.each { |entry|
        next if not entry.match /\.(jpe?g|png)$/i
        next if skiplist.include? entry

        total_images += 1
        filename = "#{path}/#{entry}"
        small_filename = "#{output_small}/#{entry}"
        medium_filename = "#{output_medium}/#{entry}"
        large_filename = "#{output_large}/#{entry}"

        image = Image.read(filename).first
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
            small_image = Image.ping(small_filename).first
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

        images_by_date[taken.strftime] << {
            :taken => taken,
            :data => {
                :filename => entry,
                :small_width => small_image.columns,
                :small_height => small_image.rows
            }
        }

        small_image.destroy!
        image.destroy!

        if num_allocated > 0 then
            puts "Num allocated: #{num_allocated}"
        end
    }

    if total_images == 0 then
        puts "No images, ignoring album"
        next
    end

    images_by_date = images_by_date.sort.map {|day, images|
        {
            :date => Date.strptime(day),
            :images => images.sort_by {|image| image[:taken]}.map {|image| image[:data]}
        }
    }

    album_html = Template.new('album.haml').render({:title => info['title'], :images_by_date => images_by_date})
    File.open(output_html, 'w') { |f| f.write(album_html) }

    range_start = first_taken.strftime('%e')
    if first_taken.year == last_taken.year then
        if first_taken.month != last_taken.month then
            range_start << first_taken.strftime('. %b')
        end
    else
        range_start << first_taken.strftime('. %b, %Y')
    end

    date_range = "#{range_start} - #{last_taken.strftime('%e. %b, %Y')}"
    albums_by_year[first_taken.strftime('%Y')] << {:name => info['title'], :link => info['link'], :date => date_range, :first => first_taken}

    info['first'] = first_taken
    info['date'] = date_range
    File.open(settings_file, 'w') {|file| file.write(YAML.dump(info)) }
}

puts "All done! Generating index."

years_content = []
index_template = Template.new 'index.per_year.haml'
albums_by_year = albums_by_year.sort_by { |e| e[0] }.reverse.map {|year, albums| {:year => year, :albums => albums.sort_by {|album| album[:first]}.reverse } }

index_content = Template.new('index.haml').render({:title => "bilder.o7.no", :albums_by_year => albums_by_year})
File.open("output/index.html", 'w') { |f| f.write(index_content) }
