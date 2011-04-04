require 'ftools'
require 'yaml'
require 'rmagick'

module Galleruby
  TRACK_ALLOCATIONS = false
  EXIF_DATE_FORMAT = '%Y:%m:%d %H:%M:%S'

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
              # YAML serializes DateTime as Time, so we convert back.
              @info['first'] = @info['first'].to_datetime if @info.has_key?('first')
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

          # TODO: Check for 'first' etc in @info.

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
          output_thumb = "#{output_album}/small"
          output_medium = "#{output_album}/medium"
          output_large = "#{output_album}/large"

          File.makedirs(output_thumb, output_medium, output_large)

          @images_by_date = Hash.new {|hash, key| hash[key] = [] }
          first_taken, last_taken = nil, nil

          # We go over each (loosely defined) valid image in the directory, and
          # generate any thumbnail, medium or large versions needed. In addition, we
          # find the range of the EXIF DateTime header for the album, so that we
          # can store that as metadata for the album.
          to_process.each do |entry|
              filename = "#{@path}/#{entry}"
              thumb_filename = "#{output_thumb}/#{entry}"
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

              if file_needs_updating?(thumb_filename, original_mtime) then
                  thumb_image = image.resize_to_fit(*config['thumb'])
                  thumb_image.write(thumb_filename)
              else
                  thumb_image = Magick::Image.ping(thumb_filename).first
              end

              taken = thumb_image.get_exif_by_entry('DateTimeOriginal').first[1]
              taken = DateTime.strptime(taken, EXIF_DATE_FORMAT)

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

              @images_by_date[taken.strftime('%F')] << {
                  :taken => taken,
                  :data => {
                      :filename => entry,
                      :thumb_width => thumb_image.columns,
                      :thumb_height => thumb_image.rows
                  }
              }

              thumb_image.destroy!
              if not image.nil? and (image.is_a?(LazyObject) and image.was_initialized?) then
                  image.destroy!
              end

              if TRACK_ALLOCATIONS and num_allocated > 0 then
                  puts "#{name}: Num allocated: #{num_allocated}"
              end
          end

          @info['first'] = first_taken
          if first_taken.strftime('%F') == last_taken.strftime('%F') then
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

      def link
        @info['link']
      end

      # Data needed for generation of the index document.
      def template_info
          {:name => @info['title'], :link => @info['link'], :date => @info['date'], :first => @info['first']}
      end
  end

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
end
