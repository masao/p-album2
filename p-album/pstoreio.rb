#
# pstoreio.rb: PhotoAlbum IO class of pstore backend. $Revision$
#
require 'pstore'

module PhotoAlbum
   class PStoreIO
      def initialize( album )
         @data_path = album.conf.data_path
         @data = {}
      end

      def load( month )
         return @data[month] if @data[month]
         filename = "#{@data_path}#{month}.db".untaint
         result = nil
         begin
            PStore::new( filename ).transaction do |db|
               if db.root?( 'p-album' ) then
                  result = db['p-album']
               end
               result ||= Month::new( month )
            end
         rescue PStore::Error, NameError, Errno::EACCES
            raise PermissionError::new( "make your @data_path to writable via httpd. #$!" )
         end
         begin
            File::delete( filename ) if result.empty?
         rescue Errno::ENOENT
         end
         @data[month] = result
         return result
      end

      def save( month, data )
         filename = "#{@data_path}#{month}.db".untaint
         begin
            PStore::new( filename ).transaction do |db|
               @data[month] = data
               db['p-album'] = data
            end
         rescue PStore::Error, NameError, Errno::EACCES
            raise PermissionError::new( "make your @data_path to writable via httpd. #$!" )
         end
      end

      def month_list
         result = []
         Dir::glob( "#{@data_path}??????.db" ).each do |f|
            month = f.scan( /(\d{6})\.db$/ )[0]
            result.push month[0] if month
         end
         result
      end
   end
end
