# $Id$

require 'cgi'
require 'ftools'
require 'date'
require 'pstore'
require 'nkf'
require 'erb'
require 'exifparser'
require 'image_size'

class String
	def to_euc
		NKF::nkf( '-m0 -e', self )
	end
end

class CGI
	def valid?( param, idx = 0 )
		self[param] and self[param][idx] and self[param][idx].length > 0
	end
end

class ImageSize
	def html_imgsize
		%Q[width="#{get_width}" height="#{get_height}"]
	end
end

module PhotoAlbum
	PATH = File::dirname( __FILE__ )

	VERSION = '1.0'

	class PhotoFile
		IMAGES_DIR = './images/'
		THUMBS_DIR = './thumbs/'
		CONVERT = '/usr/local/bin/convert'
		THUMBNAIL_OPT = "-geometry '96x96>' +profile '*'"

		attr_reader :path, :datetime
		attr_accessor :title, :description

		def initialize( file )
			STDERR.puts self.class
			STDERR.puts file
         begin
				exif = Exif::Parser::new( file )
				datetime = exif['DateTime'].value
				@datetime = Time::local( *(datetime.split(/\D+/)) )
			rescue Exif::Error
				@datetime = File::mtime( file )
			rescue RuntimeError
				@datetime = File::mtime( file )
			end

			filename = IMAGES_DIR + @datetime.strftime( '%Y%m%dt%H%M%S.jpg' )
			filename = new_fname( file, filename )
			@path = filename
			File::cp( file, @path )
			stat = File::stat( file )
			File::utime( stat.atime, stat.mtime, @path )
			make_thumbnail
		end

		# compare existing photos and get a new filename.
		def new_fname( old, new )
         if FileTest::exist?( new ) then
				target = new
				target = new + ".orig" if FileTest::exist?( new + ".orig" )
				STDERR.puts "old=#{old}, new=#{new}, target=#{target}"
				if File::cmp( old, target ) then
					raise PhotoFileException, 'file is already exist.'
				else
					1.upto 999 do |i|
						new = new.sub( /(_\d+)?.jpg$/, "_#{i}.jpg" )
						target = new + ".orig" if FileTest::exist?( new + ".orig" )
						break if not FileTest::exist?( new )
						if File::cmp( old, target ) then
							raise PhotoFileException, 'file is already exist.'
						end
					end
            end
			end
			new
		end

		def orig_path ( force = false )
			if force or FileTest::exist?( "#{path}.orig" ) then
				path + ".orig"
			else
				path
			end
		end

		def thumbnail
			THUMBS_DIR + File::basename( path )
		end

		def basename
			File::basename( path, '.*' )
		end

		def <=> ( other )
			self.datetime <=> other.datetime
		end

		def make_thumbnail
			system "#{CONVERT} #{THUMBNAIL_OPT} #{orig_path} #{thumbnail}"
		end

		def convert ( opt = "" )
			File::copy( path, orig_path( true ) ) unless FileTest::exist? orig_path
			system "#{CONVERT} #{opt} #{orig_path} #{path}"
			make_thumbnail
		end
	end

	class PhotoFileException < Exception; end

	class Day
		attr_reader :day
		def initialize ( day )
			@day = day
			@photos = []
		end

		def << ( photo )
			@photos << photo
		end

		def each_photo
			@photos.sort.each do |i|
				yield i
			end
		end

		def to_s
			@day[0,4] + '-' + @day[4,2] + '-' + @day[6,2]
		end
	end

	class Month
		attr_reader :month
		def initialize ( month )
			@month = month
			@days = {}
		end

		def << ( day )
			@days[day.day] = day 
		end

		def include? ( day )
			@days.has_key?( day )
		end

		def [] ( day )
			@days[day]
		end

		def []= ( day, val )
			@days[day] = val
		end

		def day_list
			@days.keys
		end

		def each_day
			@days.keys.sort.each do |day|
				yield @days[day]
			end
		end
	end

	class Config
		def initialize
			load
			instance_variables.each do |v|
				v.sub!( /@/, '' )
				instance_eval( <<-SRC
					def #{v}
						@#{v}
					end
					def #{v}=(p)
						@#{v} = p
					end
					SRC
				)
			end
		end

		# loading p-album.conf in current directory
		def load
			@secure = true unless @secure
			@options = {}
			eval( File::open( "p-album.conf" ){|f| f.read }.untaint )
			@index = './' unless @index
			@update = './update.rb' unless @update
			@html_title = '' unless @html_title
			@index_page = '' unless @index_page
			@recent = 5 unless @recent
			@header = '' unless @header
			@footer = '' unless @footer
			@theme = 'default' if not @theme and not @css
		end

		# loading p-album.conf in @data_path.
		def load_cgi_conf
			raise AlbumError, 'No @data_path variable.' unless @data_path
			@data_path += '/' if /\/$/ !~ @data_path
			raise AlbumError, 'Do not set @data_path as same as MoBo system directory.' if @data_path == "#{PATH}/"
			variables = [
				:html_title, :index_page, :recent,
				:header, :footer, :theme, :css
			]
			begin
				cgi_conf = File::open( "#{@data_path}p-album.conf" ){|f| f.read }
				cgi_conf.untaint unless @secure
				def_vars = ""
				variables.each do |var|
					def_vars << "#{var} = nil\n"
				end
				eval( def_vars )
				Safe::safe( @secure ? 4 : 1 ) do
					eval( cgi_conf )
				end
				variables.each do |var|
					eval "@#{var} = #{var} if #{var} != nil"
				end
			rescue IOError, Errno::ENOENT
			end
		end
	end

	class AlbumBase
		def initialize( cgi, rhtml, conf )
			@cgi, @rhtml, @conf = cgi, rhtml, conf

			month = @cgi.valid?( 'month' ) ? @cgi['month'][0] : ""
			if !Date.exist?( month[0,4].to_i, month[4,2].to_i, 1) then
				month = Time::now.strftime( '%Y%m' )
			end

			if FileTest::exist?( "#{@conf.data_path}#{month}.db" )
				db = PStore::new( "#{@conf.data_path}#{month}.db" )
				db.transaction do
					@month = db['p-album']
				end
			else
				@month = Month::new( month )
			end
		end

		def month_list
			result = []
			Dir::glob( "#{@conf.data_path}??????.db" ).each do |f|
				result << File::basename( f, '.db' )
			end
			result
		end

		def each_month
			month_list.sort.each do |m|
				yield m
			end
		end

		def eval_rhtml( prefix = '' )
			begin
				files = ["header.rhtml", @rhtml, "footer.rhtml"]
				rhtml = files.collect {|file|
					path = "#{PATH}/skel/#{prefix}#{file}"
					File::open( path ) {|f| f.read }
				}.join
				r = ERB::new( rhtml.untaint ).result( binding )
				# erb again for @conf.header and @conf.footer
				r = ERB::new( r.untaint ).result( binding )
			rescue Exception
				raise
			end
			return r
		end

		def mode
			self.class.to_s.sub( /^PhotoAlbum::Album/, '' ).downcase
		end

		def photo_list( month )
			result = []
			db = PStore::new( "#{@conf.data_path}#{month}.db" )
			db.transaction do
				db['p-album'].each_day do |day|
					day.each_photo do |photo|
						result << photo.basename
					end
				end
			end
			result
		end

		def calc_links
			if mode == 'month' then
				y, m = @month.month[0, 4], @month.month[4, 2]
				if m == "01" then
					@prev_month = "#{ sprintf('%04d', y.to_i-1) }12"
				else
					@prev_month = "#{y}#{ sprintf('%02d', m.to_i-1) }"
				end
				if m == "12" then
					@next_month = "#{y.succ}01"
				else
					@next_month = "#{y}#{m.succ}"
				end
			end

			if @photo then
				m = @photo.basename[0, 6]
				mlist = month_list
				plist = photo_list( m )
				idx = plist.index( @photo.basename )
				if idx == 0 then
					if mlist.index( m ) != 0 then
						@prev_photo = photo_list( mlist[ mlist.index(m) - 1 ] ).last
					end
				else
					@prev_photo = plist[ idx - 1 ]
				end
				if idx == plist.size - 1 then
					if mlist.index( m ) != mlist.size - 1 then
						@next_photo = photo_list( mlist[ mlist.index(m) + 1 ] ).last
					end
				else
					@next_photo = plist[ idx + 1 ]
				end
			end

			@years = {}
			month_list.sort.each do |month|
				year = month[0, 4]
				@years[year] = [] unless @years[year]
				@years[year] << month
			end
		end

		#
		# default plugin-like settings
		#
		def navi
			calc_links
			result = %Q[<div class="adminmenu">\n]
			result << %Q[<span class="adminmenu"><a href="#{@conf.index_page}">トップ</a></span>\n] unless @conf.index_page.empty?
			result << %Q[<span class="adminmenu"><a href="#{@index}?photo=#{@prev_photo}">&laquo;前の写真</a></span>\n] if @prev_photo
			result << %Q[<span class="adminmenu"><a href="#{@index}?month=#{@prev_month}">&laquo;前月</a></span>\n] if @prev_month
			result << %Q[<span class="adminmenu"><a href="#{@conf.index}">最新</a></span>\n] unless mode == 'latest'
			result << %Q[<span class="adminmenu"><a href="#{@index}?photo=#{@next_photo}">次の写真&raquo;</a></span>\n] if @next_photo
			result << %Q[<span class="adminmenu"><a href="#{@index}?month=#{@next_month}">次月&raquo;</a></span>\n] if @next_month
			result << %Q[<span class="adminmenu"><a href="#{@conf.update}">新規追加</a></span>\n] if mode != 'edit'
			result << %Q[<span class="adminmenu"><a href="#{@conf.update}?photo=#{@photo.basename}">編集</a></span>\n] if @photo
			result << %Q[<span class="adminmenu"><a href="#{@conf.update}?conf=1">設定</a></span>\n]
			result << %Q[</div>]
		end

		def calendar
			result = %Q[<div class="calendar">\n]
			@years.keys.each do |year|
				result << %Q[<div class="year">#{year} |]
				"01".upto( "12" ) do |m|
					if @years[year].include?( "#{year}#{m}" ) then
						result << %Q[<a href="#{@conf.index}?month=#{year}#{m}">#{m}</a>|]
					else
						result << %Q[#{m}|]
					end
				end
				result << "</div>"
			end
			result << "</div>"
			result
		end

		def theme_url; 'theme'; end

		def css_tag
			if @conf.theme and @conf.theme.length > 0 then
				css = "#{theme_url}/#{@conf.theme}/#{@conf.theme}.css"
				title = css
			else
				css = @css
			end
			title = CGI::escapeHTML( File::basename( css, '.css' ) )
			<<-CSS
<meta http-equiv="content-style-type" content="text/css">
<link rel="stylesheet" href="#{css}" title="#{title}" type="text/css" media="all">
CSS
		end
	end

	class AlbumError < StandardError; end

	class AlbumLatest < AlbumBase
		def initialize ( cgi, rhtml, conf )
			super

			@days = {}
			each_month do |m|
				db = PStore::new( "#{@conf.data_path}#{m}.db" )
				db.transaction do
					db['p-album'].each_day do |day|
						@days[day.to_s] = day
					end
				end
			end
		end

		def latest( recent )
			i = 0
			@days.keys.sort.reverse.each do |day|
				break if i > recent
				yield @days[day]
				i += 1
			end
		end
	end

	class AlbumMonth < AlbumBase
		def initialize( cgi, rhtml, conf )
			super

			m = @cgi['month'][0]
			if Date::exist?( m[0,4].to_i, m[4,2].to_i, 1) and FileTest::exist?( "#{@conf.data_path}#{m}.db" )then
				db = PStore::new( "#{@conf.data_path}#{m}.db" )
				db.transaction do
					@month = db['p-album']
				end
			else
				@month = Month::new( m )
			end
		end
	end

	class AlbumOne < AlbumBase
		def initialize( cgi, rhtml, conf )
			super
			m = @cgi['photo'][0][0, 6]
			d = @cgi['photo'][0][0, 8]
			db = PStore::new( "#{@conf.data_path}#{m}.db" )
			db.transaction do
				if db['p-album'].include?( d ) then
					db['p-album'][d].each_photo do |photo|
						if photo.basename == @cgi['photo'][0] then
							@photo = photo
							break
						end
					end
				end
			end
			unless @photo then
				raise AlbumError, 'No photo found.'
			end
		end
	end

	class AlbumImport < AlbumBase
		def initialize ( cgi, rhtml, conf )
			super
			raise AlbumError, 'No @import_dir in p-album.conf' unless @conf.import_dir
			@conf.import_dir += '/' unless /\/$/ =~ @conf.import_dir

			@imported = {}
			Dir::glob( "#{@conf.import_dir}*.{JPG,jpg}" ).sort.each do |f|
				STDERR.puts f
				begin
					@imported[f] = photo = PhotoFile::new( f )
					time = photo.datetime
					m = time.strftime( '%Y%m' )
					d = time.strftime( '%Y%m%d' )
					db = PStore::new( "#{@conf.data_path}#{m}.db" )
					db.transaction do
						begin month = db['p-album']; rescue; end
						unless month then
							month = Month::new( m )
						end
						if month.include?( d ) then
							day = month[d]
						else
							day = Day::new( d )
						end
						day << photo
						month << day
						db['p-album'] = month
					end
				rescue PhotoFileException
					@imported[f] = nil
				end
			end
		end
	end

	class AlbumForm < AlbumBase
	end

	class AlbumEdit < AlbumBase
		def initialize ( cgi, rhtml, conf )
			super
			m = @cgi['photo'][0][0, 6]
			d = @cgi['photo'][0][0, 8]
			db = PStore::new( "#{@conf.data_path}#{m}.db" )
			db.transaction do
				if db['p-album'].include?( d ) then
					db['p-album'][d].each_photo do |photo|
						if photo.basename == @cgi['photo'][0] then
							@photo = photo
							break
						end
					end
				end
			end
			unless @photo then
				raise AlbumError, 'No photo found.'
			end
		end
	end

	class AlbumSavePhoto < AlbumEdit
		def initialize ( cgi, rhtml, conf )
			super

			@photo.title = @cgi['title'][0].to_euc
			@photo.description = @cgi['description'][0].to_euc

			m = @cgi['photo'][0][0, 6]
			d = @cgi['photo'][0][0, 8]
			db = PStore::new( "#{@conf.data_path}#{m}.db" )
			db.transaction do
				newday = Day::new( d )
				db['p-album'][d].each_photo do |photo|
					if photo.basename == @cgi['photo'][0] then
						photo = @photo
					end
					newday << photo
				end
				db['p-album'][d] = newday
			end
		end
	end
end
