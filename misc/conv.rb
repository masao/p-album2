#!/usr/local/bin/ruby
# $Id$

# p-album から p-album2 への移行用スクリプト
#
# 使い方:
#
# このスクリプトを p-album.rb と同一のディレクトリに置いてから、以下の
# ように、以前使用していた metadata.yaml をコマンドラインから指定します。
# 
#  conv.rb ~/photo/metadata.yaml

require 'ftools'
require 'yaml'
if FileTest::symlink?( __FILE__ ) then
   org_path = File::dirname( File::readlink( __FILE__ ) )
else
   org_path = File::dirname( __FILE__ )
end
org_path = File::join( org_path, ".." )
$:.unshift( org_path.untaint )
require 'p-album'

include PhotoAlbum

if ARGV[0] and File::basename( ARGV[0] ) == "metadata.yaml"
   conf = Config::new
   month_list = {}
   yaml = ARGV[0]
   orig_dir = File::dirname( yaml )
   hash = YAML::load( open(yaml) )
   hash.keys.sort.each do |k|
      v = hash[k]
      datetime = v['datetime']
      fname = datetime.strftime( PhotoFile::FILENAME_PATTERN )
      name = File::basename( fname, PhotoFile::EXT )
      title = v['title']
      description = v['description']

      vals = v.keys - [ 'datetime', 'title', 'description', 'convert' ]
      if vals.size > 0
	 STDERR.puts "Unknown metadata entries for #{name}: #{vals.inspect} (ignored)"
      end

      begin
         if File::exist? File::join( orig_dir, k + ".orig" )
            File::cp( File::join(orig_dir, k + ".orig"),
                      conf.images_dir + fname + ".orig",
                      true )
         end
         File::cp( File::join(orig_dir, k),
                   conf.images_dir + fname,
                   true )
         File::cp( File::join(orig_dir, "thumbs", k),
                   conf.thumbs_dir + fname,
                   true )
      rescue Errno::ENOENT
         puts "skip: copy failed: #{$!}"
      end

      photo = Photo::new( name, datetime, title, description )
      m = photo.datetime.strftime('%Y%m')
      d = photo.datetime.strftime('%Y%m%d')
      month_list[m] = Month::new( m ) unless month_list.key?( m )
      month_list[m] << Day::new( d ) unless month_list[m].include?( d )
      month_list[m][d] << photo
      p = photo.to_photofile( conf )
      begin
         File::chmod( conf.perm, p.path, p.orig_path, p.thumbnail ) if conf.perm
      rescue Errno::ENOENT
         puts "skip: chmod fail: #{$!}"
      end
   end

   month_list.each do |m, month|
      PStore::new( "#{conf.data_path}#{m}.db" ).transaction do |db|
	 db['p-album'] = month
      end
      File::chmod( conf.perm, "#{conf.data_path}#{m}.db" ) if conf.perm
   end
else
   puts "Usage: #{$0} ~/photo/metadata.yaml"
   exit
end
