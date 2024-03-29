#!/usr/bin/env ruby
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
   if cgi.valid?( 'search' ) then
      album = PhotoAlbum::AlbumSearch::new( cgi, "search.rhtml", conf )
   elsif cgi.valid?( 'photo' ) then
      album = PhotoAlbum::AlbumPhoto::new( cgi, "photo.rhtml", conf )
   elsif cgi.valid?( 'date' ) and cgi.params['date'][0] =~ /^\d{6}$/ then
      album = PhotoAlbum::AlbumMonth::new( cgi, "month.rhtml", conf )
   else
      album = PhotoAlbum::AlbumLatest::new( cgi, "latest.rhtml", conf )
   end

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
   puts "Status: 500 Internal Server Error\r\n"
   puts "Content-Type: text/plain\r\n\r\n"
   puts "#$! (#{$!.class})"
   puts ""
   puts $@.join( "\n" )
end
