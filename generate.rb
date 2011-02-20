#!/usr/bin/env ruby

require 'pp'
require 'ftools'
require 'yaml'

require 'rubygems'
require 'RMagick'
require 'haml'

include Magick

SMALL_SIZE = '320x256'
MEDIUM_SIZE = '800x600'
LARGE_SIZE = '1280x1024'
EXIF_DATE_FORMAT = '%Y:%m:%d %H:%M:%S'

class Template
    @@cache = {}

    def initialize(file)
        if not @@cache.has_key? file then
            @@cache[file] = Haml::Engine.new(File.read(file))
        end

        @SMALL_SIZE = SMALL_SIZE
        @MEDIUM_SIZE = MEDIUM_SIZE
        @LARGE_SIZE = LARGE_SIZE

        @engine = @@cache[file]
    end

    def render(locals={})
        @engine.render(self, locals)
    end
end

footer = Template.new('footer.haml').render

albums = Hash.new { |hash, key| hash[key] = [] }
Dir.new('.').each { |album|
    settings_file = "#{album}/.galleruby.yaml"

    next if not File.directory? album
    next if not File.exist? settings_file

    info = YAML::load(File.read(settings_file))

    output_album = "output/#{info['link']}"
    output_small = "#{output_album}/small"
    output_medium = "#{output_album}/medium"
    output_large = "#{output_album}/large"
    output_html = "#{output_album}/index.html"

    album_dir = Dir.new(album)
    if File.exist? output_html then
        last_generated = File.mtime output_html

        needs_updating = false
        album_dir.each { |entry|
            next if not entry.match /\.(jpe?g|png)$/i

            if last_generated < File.mtime("#{album}/#{entry}") then
                needs_updating = true
                break
            end
        }

        if not needs_updating 
            albums[info['year']] << {:name => info['title'], :link => info['link'], :date => info['date']}
            next
        end
    end

    File.makedirs output_small, output_medium, output_large

    images = Hash.new {|hash, key| hash[key] = [] }
    first_taken, last_taken = nil, nil
    album_dir.each { |entry|
        next if not entry.match /\.(jpe?g|png)$/i

        filename = "#{album}/#{entry}"
        small_filename = "#{output_small}/#{entry}"
        medium_filename = "#{output_medium}/#{entry}"
        large_filename = "#{output_large}/#{entry}"

        image = Image.read(filename).first.auto_orient

        taken = image.get_exif_by_entry('DateTime').first[1]
        taken = Date.strptime(taken, EXIF_DATE_FORMAT)

        if not File.exist? large_filename then
            image.resize_to_fit!(LARGE_SIZE)
            image.write(large_filename)
        end

        if not File.exist? medium_filename then
            medium_image = image.resize_to_fit(MEDIUM_SIZE)
            medium_image.write(medium_filename)
        end

        if not File.exist? small_filename then
            small_image = image.resize_to_fit(SMALL_SIZE)
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

        template = Template.new 'album.per_day.per_image.haml'
        images[taken.strftime] << {:taken => taken, :html => template.render({:filename => entry, :small_width => small_image.columns, :small_height => small_image.rows})}
    }

    album_content = []
    images.sort.each {|day, image_list|
        image_list = image_list.sort_by { |image| image[:taken] }
        images_html = image_list.map {|image| image[:html] }.join("\n")
        album_content << Template.new('album.per_day.haml').render({:date => Date.strptime(day), :images => images_html})
    }

    album_html = Template.new('album.haml').render({:title => info['title'], :images => album_content.join("\n"), :footer => footer})
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
    albums[first_taken.year] << {:name => info['title'], :link => info['link'], :date => date_range}

    info['year'] = first_taken.year
    info['date'] = date_range
    File.open(settings_file, 'w') {|file| file.write(YAML.dump(info)) }
}

years_content = []
index_template = Template.new 'index.per_year.haml'
albums.each { |year, album_list|
    albums_template = Template.new 'index.per_year.per_album.haml'
    albums_content = album_list.map { |album| albums_template.render(album) }.join("\n")
    years_content << index_template.render({:year => year, :albums => albums_content})
}

index_content = Template.new('index.haml').render({:title => "bilder.o7.no", :albums => years_content.join("\n"), :footer => footer})
File.open("output/index.html", 'w') { |f| f.write(index_content) }
