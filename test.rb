#!/usr/local/bin/ruby
# $Id$

require 'test/unit/testsuite'
require 'test/unit/testcase'
require 'ftools'

require 'p-album'

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

class TestPhotoFile < Test::Unit::TestCase
   include PhotoAlbum
   def setup
      @tmpdir = File::join( "/tmp", self.class.to_s.downcase + "_" + $$.to_s )
      Dir::mkdir( @tmpdir )
      images_dir = File::join( @tmpdir, "images/" )
      thumbs_dir = File::join( @tmpdir, "thumbs/" )
      Dir::mkdir( images_dir )
      Dir::mkdir( thumbs_dir )

      c = Struct::new( "Config", :images_dir, :thumbs_dir, :perm, :convert, :thumbnail_opts )
      @conf = c::new( images_dir, thumbs_dir, 0600, "convert",
                      [ "-geometry", "96x96>", "+profile", "*" ] )

      @photo = PhotoFile::load_file( "DSC05003.JPG", @conf )
   end

   def teardown
      rm_rf @tmpdir
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

class TestPhotoAlbumSearch < Test::Unit::TestCase
   include PhotoAlbum
end


if $0 == __FILE__
   suite = Test::Unit::TestSuite.new('PhotoAlbum')
   ObjectSpace.each_object(Class) do |klass|
      suite << klass.suite if (Test::Unit::TestCase > klass)
   end
   require 'test/unit/ui/console/testrunner'
   Test::Unit::UI::Console::TestRunner.run(suite).passed?
end
