#!/usr/local/bin/ruby
# $Id$

# PStore が壊れてしまったのを修復するために、
# 一旦 yaml 形式に落としたデータを PStore 形式に戻すスクリプト

require "yaml"
require "p-album"

Dir::glob("*.yaml") do |f|
   result = YAML::load(open(f))

   m = File::basename(f, ".yaml")
   newfname = "new/#{m}.db"
   PStore::new( newfname ).transaction do |db|
      db['p-album'] = PhotoAlbum::Month::new( m )
      result.each do |name, p|
         photo = PhotoAlbum::Photo::new( name, p["datetime"], p["title"], p["description"] )
         d = photo.datetime.strftime('%Y%m%d')
         db['p-album'][d] ||= PhotoAlbum::Day::new( d )
         db['p-album'][d] << photo
      end
   end
   puts "#{newfname} done."
end
