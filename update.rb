#!/usr/local/bin/ruby
# $Id$

begin
   if FileTest::symlink?( __FILE__ ) then
      org_path = File::dirname( File::readlink( __FILE__ ) )
   else
      org_path = File::dirname( __FILE__ )
   end
   $:.unshift( org_path.untaint )
   require 'p-album'

   conf = PhotoAlbum::Config::new
   cgi = CGI::new
   if cgi.valid?( 'remove' )
      album = PhotoAlbum::AlbumRemovePhoto::new( cgi, "remove.rhtml", conf )
   elsif cgi.valid?( 'savephoto' )
      album = PhotoAlbum::AlbumSavePhoto::new( cgi, "edit.rhtml", conf )
   elsif cgi.valid?( 'convertphoto' )
      album = PhotoAlbum::AlbumConvertPhoto::new( cgi, "edit.rhtml", conf )
   elsif cgi.valid?( 'original' )
      album = PhotoAlbum::AlbumOriginalPhoto::new( cgi, "edit.rhtml", conf )
   elsif cgi.valid?( 'photo' )
      album = PhotoAlbum::AlbumEdit::new( cgi, "edit.rhtml", conf )
   elsif cgi.valid?( 'saveconf' ) then
      album = PhotoAlbum::AlbumSaveConf::new( cgi, "conf.rhtml", conf )
   elsif cgi.valid?( 'conf' ) then
      album = PhotoAlbum::AlbumConf::new( cgi, "conf.rhtml", conf )
   else
      album = PhotoAlbum::AlbumUpdate::new( cgi, "update.rhtml", conf )
   end
   
   STDERR.puts album.mode

   head = {
      'type' => 'text/html',
   }
   body = album.eval_rhtml
   head['charset'] = 'EUC-JP'
   head['Content-Length'] = body.size.to_s
   head['Pragma'] = 'no-cache'
   head['Cache-Control'] = 'no-cache'

   print cgi.header( head )
   print body if /HEAD/i !~ cgi.request_method

rescue
   puts "Content-Type: text/plain\r\n\r\n"
   puts "#$! (#{$!.class})"
   puts ""
   puts $@.join( "\n" )
end
