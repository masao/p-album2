#!/usr/local/bin/ruby
# $Id$

# PStore が壊れてしまったのを修復するために、一旦 yaml 形式に落とすスクリプト

require "yaml"
require "p-album"
require 'getopts'

getopts('q')

Dir::glob("*.db").sort.each do |f|
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
         if p.datetime.strftime('%Y%m%dt%H%M%S') != p.name
            STDERR.puts "name and datetime are inconsistency:"
            STDERR.puts "\tname:#{p.name} != datetime:#{p.datetime.strftime('%Y%m%dt%H%M%S')}"
         end
      end
   end

   newfname = f.sub(/db$/, "yaml")
   open(newfname, "w") do |f|
      f.print result.to_yaml( :SortKeys => true )
   end
   puts "#{newfname} done." unless $OPT_q
end
