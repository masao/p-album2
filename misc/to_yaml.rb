#!/usr/local/bin/ruby
# $Id$

# PStore が壊れてしまったのを修復するために、一旦 yaml 形式に落とすスクリプト

require "yaml"
require "p-album"

Dir::glob("*.db") do |f|
   result = {}

   month = Marshal::load(open(f))['p-album']
   # PStore::new( f ) do |db|
   #   month = db['p-album']
   #p month
   month.each_day do |d|
      d.each_photo do |p|
         result[p.name] = {
            "datetime" => p.datetime,
            "title" => p.title,
            "description" => p.description,
         }
      end
   end

   newfname = f.sub(/db$/, "yaml")
   open(newfname, "w") do |f|
      f.print result.to_yaml( :SortKeys => true )
   end
   puts "#{newfname} done."
end
