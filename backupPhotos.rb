#!/usr/bin/ruby

require 'optparse'
require_relative 'lib/photostore'

def validate_options(options)
  if options[:directory].empty?
    puts "You must specify at least one directory, options specified #{options.inspect}"
    exit 1
  end
  if options[:output_dirname].nil?
    puts "You must specify the output directory, options specified #{options.inspect}"
    exit 1
  end
end

def get_options
  # Set default options
  options = {
    directory: [],
    verbose: false,
    find_duplicates: false
  }

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{ARGV[0]} [options]"

    opts.on('-d', '--directory <directory>', 'Required | Directory to scan (can specify more than one)') do |dirname|
      options[:directory] << dirname
    end
    opts.on('-o', '--output <directory>', 'Required | Create the output tree to this directory') do |dirname|
      options[:output_dirname] = dirname
    end
    opts.on('-v', '--verbose', 'Optional | Log additonal information to the terminal') do |v|
      options[:verbose] = true
    end
    opts.on('-2', '--find-duplicates', 'Optional | Report on duplicate files') do |d|
      options[:find_duplicates] = true
    end
  end.parse!

  validate_options(options)

  options[:logger] = Logger.new(STDOUT)
  options[:logger].level = Logger::INFO unless options[:verbose]

  options
end

# Standard entry point into Ruby from the command line
if __FILE__ == $0
  options = get_options

  photo_store = PhotoStore.new(options)
  options[:directory].each do |dir_name| 
    photo_store.addDirectory(dir_name)
  end
  photo_store.writeOutputDirectory
  photo_store.reportDuplicates if options[:find_duplicates]
end
