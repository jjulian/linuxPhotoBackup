#!/usr/bin/ruby

require 'optparse'
require 'date'
require 'yaml'
require_relative 'lib/photostore'

def validate_options(options)
  if options[:directory].empty?
    puts "You must specify at least one directory, options specified #{options.inspect}"
    exit 1
  end
end

def get_options
  # Set default options
  options = {
    directory: [],
    verbose: false
  }

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{ARGV[0]} [options]"

    opts.on('-d', '--directory Directory', 'Required | Directory to scan (can specify multiples)') do |d|
      options[:directory] << d
    end
    opts.on('-b', '--create-by-date-directory Directory', String, 'Optional | Create a symlink tree to the uniq photos at this directory') do |b|
      options[:by_date_dir] = b
    end
    opts.on('-v', '--verbose', 'Optional | Log additonal information out to the terminal') do |v|
      options[:verbose] = true
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

  photos = PhotoStore.new(options)
  options[:directory].each { |dir| photos.addDirectory(dir) }
  photos.makeDateDirectoryTree(options[:by_date_dir]) unless options[:by_date_dir].nil?
end
