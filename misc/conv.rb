#!/usr/local/bin/ruby
# $Id$

# p-album ���� p-album2 �ؤΰܹ��ѥ�����ץ�
#
# �Ȥ���:
#
# ���Υ�����ץȤ� p-album.rb ��Ʊ��Υǥ��쥯�ȥ���֤��Ƥ��顢�ʲ���
# �褦�ˡ��������Ѥ��Ƥ��� metadata.yaml �򥳥ޥ�ɥ饤�󤫤���ꤷ�ޤ���
# 
#  conv.rb ~/photo/metadata.yaml

require 'ftools'
require 'yaml'
require 'p-album'

include PhotoAlbum

if ARGV[0] and File::basename( ARGV[0] ) == "metadata.yaml"
   conf = Config::new
   photo_list = []
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
      rotate = scale = nil
      if v['convert']
	 options = v['convert'].split
	 while opt = options.shift
	    case opt
	    when "-rotate"
	       rotate = options.shift.to_i
	    when "-scale", "-geometry"
	       val = options.shift.sub(/%$/, "").to_i
	       scale = val
	    else
	       STDERR.puts "Unknown convert option: #{opt}"
	    end
	 end
      end

      vals = v.keys - [ 'datetime', 'title', 'description', 'convert' ]
      if vals.size > 0
	 STDERR.puts "Unknown metadata entries for #{name}: #{vals.inspect} (ignored)"
      end

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

      photo = Photo::new( name, datetime, title, description, rotate, scale )
      photo_list << photo
      p = photo.to_photofile( conf )
      File::chmod( conf.perm, p.path, p.orig_path, p.thumbnail ) if conf.perm
   end

   photo_list.each do |photo|
      m = photo.datetime.strftime('%Y%m')
      d = photo.datetime.strftime('%Y%m%d')
      PStore::new( "#{conf.data_path}#{m}.db" ).transaction do |db|
	 db['p-album'] = Month::new( m ) unless db.root?( 'p-album' )
	 db['p-album'][d] = Day::new( d ) unless db['p-album'][d]
	 db['p-album'][d] << photo
      end
      File::chmod( conf.perm, "#{conf.data_path}#{m}.db" ) if conf.perm
   end
else
   puts "Usage: #{$0} ~/photo/metadata.yaml"
   exit
end
