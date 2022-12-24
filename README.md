# Photo Backup Script

This script will scan multiple directories and hash them to identify multiple copies of the same file.  It will also read in EXIF data from the picture as well to get the time the picture was taken.

It can then build a hardlink directory structure to centralize these disparate directories into one location.

## Prerequisites

- Ruby 3 installed
- bundler installed
- Run `bundle`

## Usage

Suppose I have three directories of photos:
1. /home/user1/Pictures/
2. /home/share/Pictures/
3. /home/user3/Photos Library.photoslibrary/originals

These directories may or may not have the exact same photos. Create a directory structure with a set of hard links based on the EXIF dates:
```
bundle exec ruby backupPhotos.rb -d /home/user1/Pictures/ -d /home/share/Pictures/ -d /home/user3/Photos\ Library.photoslibrary/originals -o /home/share/bydate
```
