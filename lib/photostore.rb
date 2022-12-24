#!/usr/bin/ruby

require 'digest'
require 'fileutils'
require 'exifr/jpeg'
require 'date'
require 'progressbar'

class PhotoStore

  def initialize(options = {})
    @logger = options.fetch(:logger, Logger.new(STDOUT))
    @photos_by_hash = {}
  end

  # Adds a file into the memory datastore
  #
  def addFile(filename)
    # contents = File.read(filename) # read the full file - most reliable
    contents = File.binread(filename, 10_000) # read the first 10k of the file - causes a few false positive duplicates, but is way faster
    hash = Digest::MD5.hexdigest(contents)

    @photos_by_hash[hash] ||= {}
    @photos_by_hash[hash]['hash'] = hash
    @photos_by_hash[hash]['size'] = File.size(filename)
    @photos_by_hash[hash]['files'] ||= []
    @photos_by_hash[hash]['files'] << filename
    @photos_by_hash[hash]['date'] = extractDate(filename)
  end

  # Recursively adds all files in a directory to the metadata datastore
  #
  def addDirectory(directory)
    @logger.debug("Adding directory #{directory}")
    Dir.chdir(directory) do
      filenames = Dir.glob("**/*").select do |filename|
        # NOTE: Selection here is all non-directory files.  This will includes things
        # like movies, photo db files, etc. unless MimeMagic is used
        !File.directory?(filename)
      end

      @logger.debug("adding #{filenames.size} files")
      progressbar = ProgressBar.create(total: filenames.size, title: "Reading files")
      filenames.each_with_index do |filename, index|
        addFile(File.expand_path(filename))
        progressbar.progress = index
      end
    end
  end

  # Creates a hard link directory tree structure based on exif date from the datastore
  #
  def makeDateDirectoryTree(start_directory = '.')
    @logger.debug("Writing directory tree to #{start_directory}")
    progressbar = ProgressBar.create(total: @photos_by_hash.keys.size, title: 'Building output')
    @photos_by_hash.each_with_index do |(hash, file_info), index|
      if file_info['date'].nil? || file_info['date'] == ''
        date_path = "Unknown"
      else
        begin
          date = DateTime.parse(file_info['date'].to_s)
          date_path = sprintf("%4d/%02d", date.year, date.month)
          # destination_filename = sprintf("%4d-%02d-%02d-%02d-%02d-%02d-%s", date.year, date.month, date.day, date.hour, date.min, date.sec, hash)
        rescue => e
          @logger.warn "Error, invalid date specified in exif for file #{file_info['files'].first} (#{file_info['date'].to_s})"
          date_path = "Invalid"
        end
      end
      
      directory = start_directory + '/' + date_path
      FileUtils::mkdir_p directory unless Dir.exists?(directory)
      file = "#{directory}/#{file_info['files'].first.split('/').last}"
      begin
        FileUtils.ln(file_info['files'].first, file) unless File.exists?(file)
      rescue => e
        @logger.warn "Unable to create link for file #{file}: #{e}"
      end
      progressbar.progress = index
    end
  end


  # Returns the date data from a file
  #
  # @return [String] The date from the exif metadata or the file last modified date
  def extractDate(filename)
    begin
      exif = EXIFR::JPEG.new(filename)
      # grab the date in order of preference
      date = exif.date_time_original || exif.date_time || exif.date_time_digitized
    rescue => e
      # cannot read exif data
    end
    if date
      date.to_s
    else
      # fallback to the file's mtime - the time it was last modified
      File::Stat.new(filename).mtime.to_s
    end
  end
end
