#!/usr/bin/env ruby

require 'ftools'
require 'fileutils'
require 'yaml'

if ARGV.empty? then
    puts "Syntax: #{$0} <directory>"
    exit(1);
end

directory = ARGV[0]
Dir.new(directory).each { |album|
    settings_file = "#{directory}/#{album}/.galleruby.yml"
    skip_file = "#{directory}/#{album}/.galleruby.skip"

    next if album.start_with? '.'
    next if not File.directory? "#{directory}/#{album}"
    next if File.exist? skip_file

    info = {}
    if File.exist? settings_file then
        info = YAML::load(File.read(settings_file))
    end

    next if info.has_key? 'link' and info.has_key? 'title'

    puts "> Directory #{album}, #{Dir.entries(directory + "/" + album).length - 2} files"

    if not info.has_key? 'title' then
        default_title = album.sub(/^\d+-\d+-\d+( - \d+)?/, '').strip
        puts "   What should the title be? [#{default_title}]"
        title = STDIN.gets
        if title.nil?
            FileUtils.touch skip_file
            puts "   Skipping album"
            next
        else
            title = title.chomp
        end

        if title.empty? then
            title = default_title
        end

        info['title'] = title
    end

    if not info.has_key? 'link' then
        default_link = info['title'].sub(/^\d+-\d+-\d+( - \d+)?/, '').downcase
        default_link = default_link.sub('ø', 'oe').sub('å', 'aa').sub('æ', 'ae')
        default_link.gsub!(/[^a-z0-9_-]/, '')
        puts "   What should the link name be? [#{default_link}]"
        link = STDIN.gets
        if link.nil?
            FileUtils.touch skip_file
            puts "   Skipping album"
            next
        else
            link = link.chomp
        end

        if link.empty? then
            link = default_link
        end

        info['link'] = link
    end

    File.open(settings_file, 'w') {|file| file.write(YAML.dump(info)) }
}
