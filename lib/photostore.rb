#!/usr/bin/ruby

require 'date'
require 'fileutils'
require 'json'
require 'exifr/jpeg'
require 'digest'
require 'progressbar'

# A metadata repositoty and structured output directory for images
#
class PhotoStore

  def initialize(options = {})
    @output_dirname = options.fetch(:output_dirname, nil)
    raise "no output dirname" if @output_dirname.nil?
    @metadata_filename = "#{@output_dirname}/picture-data-cache.json"
    @logger = options.fetch(:logger, Logger.new(STDOUT))
    loadMetadataFromDisk
  end

  # Adds a file to the metadata
  #
  def addFile(filename)
    return if cached?(filename)

    # contents = File.read(filename) # read the full file - most reliable, but slow
    contents = File.binread(filename, 10_000) # read the first 10k of the file - may cause false positive duplicates, but is way faster
    hash = Digest::MD5.hexdigest(contents)

    @photos_by_hash[hash] ||= {}
    @photos_by_hash[hash]['files'] ||= []
    @photos_by_hash[hash]['files'] << filename
    @photos_by_hash[hash]['size'] = File.size(filename)
    @photos_by_hash[hash]['date'] = extractDate(filename)
    @photos_by_filename[filename] = @photos_by_hash[hash]
  end

  # Recursively adds all files in a directory to the metadata
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
      progressbar.finish
    end
    saveMetadataToDisk
  end

  # Scan the data and log the filenames that seem to be duplicates
  #
  def reportDuplicates
    duplicates = @photos_by_hash.select do |hash, info|
      first_filename = info['files'].first.split('/').last.downcase
      info['files'].size > 1 && 
        !info['files'].all? { |path| path.split('/').last.downcase == first_filename } # if all the filenames are the same, assume this is ok
    end

    duplicates.each do |(hash, info)|
      @logger.debug("possible duplicates for #{hash}")
      info['files'].each do |file_path|
        @logger.debug(file_path)
      end
    end
    @logger.debug("found #{duplicates.size} possible duplicates") if duplicates.size > 0
  end

  # Creates a hard link directory tree structure based on dates from the metadata
  #
  def writeOutputDirectory
    @logger.debug("Writing directory tree to #{@output_dirname}")
    progressbar = ProgressBar.create(total: @photos_by_hash.keys.size, title: 'Building output')
    @photos_by_hash.each_with_index do |(hash, info), index|
      if info['date'].nil? || info['date'] == ''
        date_path = "Unknown"
      else
        begin
          date = DateTime.parse(info['date'].to_s)
          date_path = sprintf("%4d/%02d", date.year, date.month)
          # destination_filename = sprintf("%4d-%02d-%02d-%02d-%02d-%02d-%s", date.year, date.month, date.day, date.hour, date.min, date.sec, hash)
        rescue => e
          @logger.warn "Error, invalid date specified in exif for file #{info['files'].first} (#{info['date'].to_s})"
          date_path = "Invalid"
        end
      end
      
      directory = @output_dirname + '/' + date_path
      FileUtils::mkdir_p directory unless Dir.exists?(directory)
      file = "#{directory}/#{info['files'].first.split('/').last}"
      begin
        FileUtils.ln(info['files'].first, file) unless File.exists?(file)
      rescue => e
        @logger.warn "Unable to create link for file #{file}: #{e}"
      end
      progressbar.progress = index
    end
    progressbar.finish
  end

  # Writes the metadata to disk
  #
  def saveMetadataToDisk
    progressbar = ProgressBar.create(title: 'Saving metadata')
    f = File.open(@metadata_filename, 'w')
    f.puts(@photos_by_hash.to_json)
    progressbar.finish
  end
  
  private

  # Loads the metadata from disk
  #
  def loadMetadataFromDisk
    @photos_by_hash ||= {}
    @photos_by_filename ||= {}
    if File.readable?(@metadata_filename)
      progressbar = ProgressBar.create(title: 'Loading metadata')
      @photos_by_hash = JSON.parse(File.read(@metadata_filename))
      @photos_by_hash.each do |hash, info|
        info["files"].each do |filename|
          @photos_by_filename[filename] = info
	      end
      end
      progressbar.finish
    end
  end

  # Is this file's metadata already loaded?
  #
  def cached?(filename)
    !!@photos_by_filename[filename]
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
