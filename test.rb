#!/usr/local/bin/ruby
# $Id$

require 'test/unit'
require 'ftools'

require 'p-album'

class CGI
   # For local test: cf.[ruby-list:34638]
   remove_const(:EOL)
   EOL = "\n"
end

def rm_rf( path )
   if FileTest::directory? path
      Dir::foreach( path ) do |f|
         rm_rf path + "/" + f unless /^\.\.?$/ =~ f
      end
      Dir::rmdir path
   elsif FileTest::file? path
      File::rm_f path
   end
end

def tmpname
   File::join( "/tmp", self.class.to_s.downcase + "_" + $$.to_s )
end

def setup_tmpdir
   tmpdir = tmpname
   Dir::mkdir( tmpdir )
   images_dir = File::join( tmpdir, "images/" )
   thumbs_dir = File::join( tmpdir, "thumbs/" )
   Dir::mkdir( images_dir )
   Dir::mkdir( thumbs_dir )
   tmpdir
end

def setup_album_conf( dir )
   open( "p-album.conf", "w" ) do |f|
      f.print <<-EOF
@data_path = '#{dir}/'
@images_dir = '#{dir}/images/'
@thumbs_dir = '#{dir}/thumbs/'
@convert = 'convert'
@thumbnail_opts = [ "-geometry", "96x96>", "+profile", "*" ]
      EOF
   end
end

class TestPhotoFile < Test::Unit::TestCase
   include PhotoAlbum
   def setup
      @tmpdir = setup_tmpdir
      setup_album_conf( @tmpdir )
      @conf = Config::new
      @photo = PhotoFile::load_file( "DSC05003.JPG", @conf )
   end
   def teardown
      rm_rf @tmpdir
      rm_rf "p-album.conf"
   end

   def test_load_file
      assert_instance_of( PhotoFile, @photo )
      assert_equal( "20040301t091255", @photo.name )

      assert_nil( PhotoFile::load_file( "DSC05003.JPG", @conf ) )

      assert( FileTest::exist?( File::join(@conf.images_dir,"20040301t091255.jpg")) )
      assert( FileTest::exist?( File::join(@conf.thumbs_dir,"20040301t091255.jpg")) )

      im = ImageSize::new( open( File::join(@conf.thumbs_dir,"20040301t091255.jpg") ) )
      assert_equal( 96, [ im.get_width, im.get_height ].max )
   end

   def test_do_convert
      @photo.do_convert( 90, nil )
      im = ImageSize::new( open( File::join(@conf.images_dir,"20040301t091255.jpg") ) )
      assert_equal( 640, im.get_height )
      assert_equal( 480, im.get_width )

      assert( FileTest::exist?( File::join(@conf.images_dir,"20040301t091255.jpg.orig")) )
      im = ImageSize::new( open( File::join(@conf.images_dir,"20040301t091255.jpg.orig") ) )
      assert_equal( 480, im.get_height )
      assert_equal( 640, im.get_width )
   end
end

class TestAlbumUpload < Test::Unit::TestCase
   include PhotoAlbum
   def setup
      @tmpdir = setup_tmpdir
      setup_album_conf( @tmpdir )
      @conf = Config::new

      tmpfile = @tmpdir + "/http.dat"
      open( tmpfile, "w" ) do |f|
         f.print <<-EOF
--boundary
Content-Disposition: form-data; name="file1"; filename="file1"
Content-Type: image/jpeg

         EOF
         f.print open('DSC05003.JPG'){|image| image.read;}
         f.print "\n--boundary--\n"
      end

      ENV['REQUEST_METHOD'] = 'POST'
      ENV['CONTENT_LENGTH'] = FileTest::size?( tmpfile ).to_s
      ENV['CONTENT_TYPE'] = 'multipart/form-data; boundary=boundary'
      $stdin = open( tmpfile )
      @album = AlbumUpload::new( CGI::new, "update.rhtml", @conf )
   end
   def teardown
      rm_rf @tmpdir
      rm_rf "p-album.conf"
   end

   def test_new
      assert( FileTest::exist?( File::join(@conf.images_dir,"20040301t091255.jpg")) )
      assert( FileTest::exist?( File::join(@conf.thumbs_dir,"20040301t091255.jpg")) )
      im = ImageSize::new( open( File::join(@conf.thumbs_dir,"20040301t091255.jpg") ) )
      assert_equal( 96, [ im.get_width, im.get_height ].max )
   end
end
