# $Id$

require 'cgi'
require 'ftools'
require 'date'
require 'pstore'
require 'nkf'
require 'image_size'
begin
   require 'erb_fast'
   ERbLight = ERB
rescue LoadError
   begin
      require 'erb'
      ERbLight = ERB
   rescue LoadError
      require 'erb/erbl'
   end
end

PHOTOALBUM_VERSION = '0.1'

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

def html_imgsize( file )
   is = ImageSize::new(open(file))
   %Q[width="#{is.get_width}" height="#{is.get_height}"]
end

#
# Safe Module
#
require 'thread'
module Safe
   def safe( level = 4 )
      result = nil
      Thread.start {
	 $SAFE = level
	 result = yield
      }.join
      result
   end
   module_function :safe
end

module PhotoAlbum
   PATH = File::dirname( __FILE__ )

   class Convert
      def initialize( path )
	 @path = path
      end
      def convert( *args )
	 STDERR.puts args.inspect
	 system(@path, *args)
      end
   end

   # 写真の情報を表現
   class Photo
      attr_reader :name, :datetime
      attr_accessor :title, :description
      attr_accessor :rotate, :scale

      def initialize( name, datetime = nil, title = nil, description = nil, rotate = nil, scale = nil )
	 @name = name
	 @datetime = datetime
	 @title, @description = title, description
	 @rotate, @scale = rotate, scale
	 unless @datetime
	    # STDERR.puts @name
	    @datetime = Time::local( *(@name.scan(/^(\d\d\d\d)(\d\d)(\d\d)t(\d\d)(\d\d)(\d\d)/)[0]) )
	 end
      end

      def <=> ( other )
	 self.datetime <=> other.datetime
      end

      def to_photofile( conf )
	 PhotoFile::new( @name, conf, @datetime, @title, @description, @rotate, @scale )
      end
   end

   # 写真ファイルの操作
   class PhotoFile < Photo
      EXT = '.jpg'
      FILENAME_REGEXP  = /\d{8}t\d{6}#{EXT}/
      FILENAME_PATTERN = "%Y%m%dt%H%M%S#{EXT}"

      def initialize( name, conf, datetime = nil, title = nil, description = nil, rotate = nil, scale = nil )
	 super( name, datetime, title, description, rotate, scale )
	 @conf = conf
      end

      def to_photo
	 Photo::new( @name, @datetime, @title, @description, @rotate, @scale)
      end

      def path
	 @conf.images_dir + name + EXT
      end

      def thumbnail
	 @conf.thumbs_dir + name + EXT
      end

      def orig_path ( force = false )
	 if force or FileTest::exist?( "#{path}.orig" ) then
	    path + ".orig"
	 else
	    path
	 end
      end

      def make_thumbnail
	 Convert::new( @conf.convert ).convert( *(@conf.thumbnail_opts.dup << orig_path << thumbnail) )
      end

      def do_convert
	 # STDERR.puts "do_convert"
	 convert = Convert.new( @conf.convert )
	 File::copy( path, orig_path( true ) ) unless FileTest::exist? orig_path
	 if @rotate then
	    convert.convert( "-rotate", @rotate.to_s, path, tempname )
	    File::cp( tempname, path )
	 end
	 if @scale then
	    convert.convert( "-scale", @scale.to_s, path, tempname )
	    File::cp( tempname, path )
	 end
	 make_thumbnail
      end

      def tempname( ext = EXT )
	 tmpdir = ENV['TMPDIR'] || "/tmp/"
	 tmpdir << @name << $$.to_s << ext
      end

      def self::load_file( file, conf )
	 datetime = nil
	 begin
	    require 'exifparser'
	    exif = Exif::Parser::new( file )
	    datetime = Time::local( *(exif['DateTime'].value.split(/\D+/)) )
	 rescue Exif::Error
	    datetime = File::mtime( file )
	 rescue RuntimeError
	    datetime = File::mtime( file )
	 end

	 filename = conf.images_dir + datetime.strftime( self::FILENAME_PATTERN )

	 # 既存の写真ファイルと同じものなら追加しない
	 if FileTest::exist?( filename ) then
	    target = filename
	    target = filename + ".orig" if FileTest::exist?( filename + ".orig" )
	    if File::cmp( file, target ) then
	       return nil
	    else
	       1.upto 999 do |i|
		  filename = filename.sub( /(_\d+)?.jpg$/, "_#{i}.jpg" )
		  target = filename + ".orig" if FileTest::exist?( filename + ".orig" )
		  break if not FileTest::exist?( filename )
		  if File::cmp( file, target ) then
		     return nil
		  end
	       end
	    end
	 end

	 File::cp( file, filename )
	 stat = File::stat( file )
	 File::utime( stat.atime, stat.mtime, filename )
	 photo = self::new( File::basename(filename, EXT), conf )
	 photo.make_thumbnail
	 photo
      end
   end

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

      # saving to p-album.conf in @data_path
      def save
	 result = ERbLight::new( File::open( "#{PATH}/skel/p-album.rconf" ){|f| f.read }.untaint ).result( binding )
	 result.untaint unless @secure
	 Safe::safe( @secure ? 4 : 1 ) do
	    eval( result )
	 end
	 File::open( "#{@data_path}p-album.conf", 'w' ) do |o|
	    o.print result
	 end
      end

      def mobile_agent?
	 %r[(DoCoMo|J-PHONE|UP\.Browser|DDIPOCKET|ASTEL|PDXGW|Palmscape|Xiino|sharp pda browser|Windows CE|L-mode)]i =~ ENV['HTTP_USER_AGENT']
      end

      #
      # get/set/delete plugin options
      #
      def []( key )
	 @options[key]
      end

      def []=( key, val )
	 @options2[key] = @options[key] = val
      end

      def delete( key )
	 @options.delete( key )
	 @options2.delete( key )
      end

      # loading p-album.conf in current directory
      def load
	 @secure = true unless @secure
	 @options = {}
	 eval( File::open( "p-album.conf" ){|f| f.read }.untaint )

	 # language setup
	 @lang = 'ja' unless @lang
	 begin
	    instance_eval( File::open( "#{PhotoAlbum::PATH}/p-album/lang/#{@lang}.rb" ){|f| f.read }.untaint )
	 rescue Errno::ENOENT
	    @lang = 'ja'
	    retry
	 end

	 @images_dir = './images/' unless @images_dir
	 @thumbs_dir = './thumbs/' unless @thumbs_dir
	 @perm = nil unless @perm

	 @index = './' unless @index
	 @update = './update.rb' unless @update

	 @index_page = '' unless @index_page
	 @author_name = '' unless @author_name
	 @recent = 5 unless @recent
	 @html_title = '' unless @html_title
	 @header = '' unless @header
	 @footer = '' unless @footer
	 @theme = 'default' if not @theme and not @css

	 @options = {} unless @options.class == Hash
	 if @options2 then
	    @options.update( @options2 )
	 else
	    @options2 = {}.taint
	 end
	 @options.taint
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

      def method_missing( *m )
	 if m.length == 1 then
	    instance_eval( <<-SRC
                             def #{m[0]}
                                @#{m[0]}
                             end
                             def #{m[0]}=( p )
                                @#{m[0]} = p
                             end
                             SRC
             )
          end
          nil
       end

   end

   #
   # class Plugin
   #  plugin management class
   #
   class Plugin
      attr_reader :cookies

      def initialize( params )
	 @header_procs = []
	 @footer_procs = []
	 @onload_procs = []
	 @update_procs = []
	 @body_enter_procs = []
	 @body_leave_procs = []
	 @edit_procs = []
	 @form_procs = []
	 @conf_keys = []
	 @conf_procs = {}
	 @menu_procs = []
	 @plugin_procs = {}
	 @cookies = []

	 params.each_key do |key|
	    eval( "@#{key} = params['#{key}']" )
	 end

	 # for ruby 1.6.x support
	 if @conf.secure then
	    @cgi.params.each_value do |p|
	       p.each {|v| v.taint}
	    end
	 end

	 # loading plugins
	 @plugin_files = []
	 plugin_path = @conf.plugin_path || "#{PATH}/plugin"
	 plugin_file = ''
	 begin
	    Dir::glob( "#{plugin_path}/*.rb" ).sort.each do |file|
	       plugin_file = file
	       load_plugin( file )
	       @plugin_files << plugin_file
	    end
	 rescue Exception
	    raise PluginError::new( "Plugin error in '#{File::basename( plugin_file )}'.\n#{$!}" )
	 end
      end

      def load_plugin( file )
	 @resource_loaded = false
	 begin
	    res_file = File::dirname( file ) + "/#{@conf.lang}/" + File::basename( file )
	    open( res_file.untaint ) do |src|
	       instance_eval( src.read.untaint )
	    end
	    @resource_loaded = true
	 rescue IOError, Errno::ENOENT
	 end
	 open( file.untaint ) do |src|
	    instance_eval( src.read.untaint )
	 end
      end

      def eval_src( src, secure )
	 self.taint
	 @conf.taint
	 @body_enter_procs.taint
	 @body_leave_procs.taint
	 return Safe::safe( secure ? 4 : 1 ) do
	    eval( src )
	 end
      end

      private
      def add_header_proc( block = Proc::new )
	 @header_procs << block
      end

      def header_proc
	 r = []
	 @header_procs.each do |proc|
	    r << proc.call
	 end
	 r.join.chomp
      end

      def add_footer_proc( block = Proc::new )
	 @footer_procs << block
      end

      def footer_proc
	 r = []
	 @footer_procs.each do |proc|
	    r << proc.call
	 end
	 r.join.chomp
      end

      def add_onload_proc( block = Proc::new )
	 @onload_procs << block
      end

      def onload_proc
	 r = []
	 @onload_procs.each do |proc|
	    r << proc.call
	 end
	 r.join.strip
      end

      def add_update_proc( block = Proc::new )
	 @update_procs << block
      end

      def update_proc
	 @update_procs.each do |proc|
	    proc.call
	 end
	 ''
      end

      def add_body_enter_proc( block = Proc::new )
	 @body_enter_procs << block
      end

      def body_enter_proc( date )
	 r = []
	 @body_enter_procs.each do |proc|
	    r << proc.call( date )
	 end
	 r.join
      end

      def add_body_leave_proc( block = Proc::new )
	 @body_leave_procs << block
      end

      def body_leave_proc( date )
	 r = []
	 @body_leave_procs.each do |proc|
	    r << proc.call( date )
	 end
	 r.join
      end

      def add_edit_proc( block = Proc::new )
	 @edit_procs << block
      end

      def edit_proc( date )
	 r = []
	 @edit_procs.each do |proc|
	    r << proc.call( date )
	 end
	 r.join
      end

      def add_form_proc( block = Proc::new )
	 @form_procs << block
      end

      def form_proc( date )
	 r = []
	 @form_procs.each do |proc|
	    r << proc.call( date )
	 end
	 r.join
      end

      def add_conf_proc( key, label, block = Proc::new )
	 return unless @mode =~ /^(conf|saveconf)$/
	 @conf_keys << key unless @conf_keys.index( key )
	 @conf_procs[key] = [label, block]
      end

      def each_conf_key
	 @conf_keys.each do |key|
	    yield key
	 end
      end

      def conf_proc( key )
	 r = ''
	 label, block = @conf_procs[key]
	 r = block.call if block
	 r
      end

      def conf_label( key )
	 label, block = @conf_procs[key]
	 label
      end

      def add_menu_proc( block = Proc::new )
	 @menu_procs << block
      end

      def menu_proc
	 r = []
	 @menu_procs.each do |proc|
	    r << proc.call
	 end
	 r.compact
      end

      def add_plugin_proc( key, block = Proc::new )
	 return unless @mode == 'plugin'
	 @plugin_procs[key] = block
      end

      def plugin_proc( key )
	 r = ''
	 block = @plugin_procs[key]
	 r = block.call if block
	 ERbLight.new( r ).result( binding )
      end

      def add_cookie( cookie )
	 begin
	    @cookies << cookie
	 rescue SecurityError
	    raise SecurityError, "can't use cookies in plugin when secure mode"
	 end
      end

      def apply_plugin( str, remove_tag = false )
	 r = str.dup
	 if @conf.options['apply_plugin'] and str.index( '<%' ) then
	    r = str.untaint if $SAFE < 3
	    r = ERbLight.new( r ).result( binding )
	 end
	 r.gsub!( /<.*?>/, '' ) if remove_tag
	 r
      end

      def method_missing( *m )
	 super if @debug
	 # ignore when no plugin
      end
   end

   #
   # exception classes
   #
   class AlbumError < StandardError; end
   class PermissionError < AlbumError; end
   class PluginError < AlbumError; end

   class AlbumBase
      attr_reader :cookies

      def initialize( cgi, rhtml, conf )
	 @cgi, @rhtml, @conf = cgi, rhtml, conf
	 @cookies = []
	 @all_photos = []
	 each_month do |m|
	    @all_photos += photo_list( m )
	 end
      end

      def eval_rhtml( prefix = '' )
	 begin
	    r = do_eval_rhtml( prefix )
	 rescue PluginError, SyntaxError, ArgumentError
	    r = ERbLight::new( File::open( "#{PATH}/skel/plugin_error.rhtml" ) {|f| f.read }.untaint ).result( binding )
	 rescue Exception
	    raise
	 end
	 r
      end

   protected
      def do_eval_rhtml( prefix )
	 # load plugin files
	 load_plugins

	 # load and apply rhtmls
	 files = ["header.rhtml", @rhtml, "footer.rhtml"]
	 rhtml = files.collect {|file|
	    path = "#{PATH}/skel/#{prefix}#{file}"
	    begin
	       File::open( "#{path}.#{@conf.lang}" ) {|f| f.read }
	    rescue
	       File::open( path ) {|f| f.read }
	    end
	 }.join
	 r = ERbLight::new( rhtml.untaint ).result( binding )
	 r = ERbLight::new( r ).src

	 # apply plugins
	 r = @plugin.eval_src( r.untaint, @conf.secure ) if @plugin
	 @cookies += @plugin.cookies
	 r
      end
      
      def mode
	 self.class.to_s.sub( /^PhotoAlbum::Album/, '' ).downcase
      end

      def load_plugins
	 calendar
	 @plugin = Plugin::new(
			       'conf' => @conf,
			       'mode' => mode,
			       'cgi' => @cgi,
			       'years' => @years,
			       'date' => @date,
			       'month' => @month,
			       'photo' => @photo,
			       'all_photos' => @all_photos
			       )
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

      def photo_list( month )
	 result = []
	 PStore::new( "#{@conf.data_path}#{month}.db" ).transaction do |db|
	    db['p-album'].each_day do |day|
	       day.each_photo do |photo|
		  result << photo.name
	       end
	    end
	 end
	 result
      end

      def calendar
	 @years = {}
	 month_list.sort.each do |m|
	    year = m[0, 4]
	    if photo_list( m ).size > 0 then
	       @years[year] = [] unless @years[year]
	       @years[year] << m
	    end
	 end
      end
   end

   class AlbumLatest < AlbumBase
      def initialize ( cgi, rhtml, conf )
	 super

	 @days = {}
	 each_month do |m|
	    PStore::new( "#{@conf.data_path}#{m}.db" ).transaction do |db|
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

	 year = month = ""
	 if @cgi.valid?( 'date' ) then
	    @date = @cgi.params['date'][0]
	    year =  @cgi.params['date'][0][0,4]
	    month = @cgi.params['date'][0][4,2]
	    month = '01' if month.empty?
	 end
	 if !Date.exist?(year.to_i, month.to_i, 1) then
	    month = Time::now.strftime( '%m' )
	 end

	 if FileTest::exist?( "#{@conf.data_path}#{year}#{month}.db" )
	    PStore::new( "#{@conf.data_path}#{year}#{month}.db" ).transaction do |db|
	       @month = db['p-album']
	    end
	 else
	    @month = Month::new( month )
	 end
      end
   end

   class AlbumPhoto < AlbumBase
      def initialize( cgi, rhtml, conf )
	 super

	 m = @cgi['photo'][0][0, 6]
	 d = @cgi['photo'][0][0, 8]
	 PStore::new( "#{@conf.data_path}#{m}.db" ).transaction do |db|
	    if db['p-album'].include?( d ) then
	       db['p-album'][d].each_photo do |photo|
		  if photo.name == @cgi['photo'][0] then
		     @photo = photo.to_photofile( @conf )
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

   #
   # class AlbumConf
   #  show configuration form
   #
   class AlbumConf < AlbumBase
      def initialize( cgi, rhtml, conf )
	 super
	 @key = @cgi.params['conf'][0]
      end
   end

   #
   # class AlbumSaveConf
   #  save configuration
   #
   class AlbumSaveConf < AlbumConf
      def initialize( cgi, rhtml, conf )
	 super
      end

      def eval_rhtml( prefix = '' )
	 r = super

	 begin
	    @conf.save
	 rescue
	    @error = [$!.dup, $@.dup]
	 end

	 r
      end
   end

   class AlbumUpdate < AlbumBase
      def initialize ( cgi, rhtml, conf )
	 super

	 filelist = Dir::glob("#{@conf.images_dir}*#{PhotoFile::EXT}").find_all{|f|
	    FileTest::file? f and PhotoFile::FILENAME_REGEXP =~ f
	 }.collect{|f|
	    File::basename( f, PhotoFile::EXT )
	 }

	 # puts "filelist: #{filelist.inspect}"
	 # puts "photolist: #{@all_photos.inspect}"
	 @added = []
	 (filelist - @all_photos).each do |name|
	    photo = Photo::new( name )
	    @added << PhotoFile::new( name, @conf )
	    m = photo.datetime.strftime('%Y%m')
	    d = photo.datetime.strftime('%Y%m%d')
	    PStore::new( "#{@conf.data_path}#{m}.db" ).transaction do |db|
	       db['p-album'] = Month::new( m ) unless db.root?( 'p-album' )
	       db['p-album'][d] = Day::new( d ) unless db['p-album'][d]
	       db['p-album'][d] << photo
	    end
	 end
      end
   end

   class AlbumPhotoEdit < AlbumPhoto; end

   class AlbumPhotoSave < AlbumPhotoEdit
      def initialize ( cgi, rhtml, conf )
	 super

	 @photo.title = @cgi['title'][0].to_euc
	 @photo.description = @cgi['description'][0].to_euc

	 m = @cgi['photo'][0][0, 6]
	 d = @cgi['photo'][0][0, 8]
	 PStore::new( "#{@conf.data_path}#{m}.db" ).transaction do |db|
	    newday = Day::new( d )
	    db['p-album'][d].each_photo do |photo|
	       if photo.name == @cgi['photo'][0] then
		  photo = @photo.to_photo
	       end
	       newday << photo
	    end
	    db['p-album'][d] = newday
	 end
      end
   end

   class AlbumPhotoOriginal < AlbumPhotoEdit
      def initialize ( cgi, rhtml, conf )
	 super
	 File::move( @photo.orig_path, @photo.path )
	 @photo.make_thumbnail
	 @photo.rotate = nil
	 @photo.scale = nil
	 @photo.convert = nil
      end
   end

   class AlbumPhotoRemove < AlbumPhotoEdit
      def initialize ( cgi, rhtml, conf )
	 super
	 if @cgi.valid?( 'confirm' ) then
	    m = @cgi['photo'][0][0, 6]
	    d = @cgi['photo'][0][0, 8]
	    PStore::new( "#{@conf.data_path}#{m}.db" ).transaction do |db|
	       newday = Day::new( d )
	       db['p-album'][d].each_photo do |photo|
		  unless photo.name == @cgi['photo'][0] then
		     newday << photo
		     newday_size += 1
		  end
	       end
	       db['p-album'][d] = newday if newday_size > 0
	    end

	    begin
	       File::unlink( @photo.orig_path )
	       File::unlink( @photo.thumbnail )
	       File::unlink( @photo.path )
	    rescue Errno::ENOENT
	    end

	    print @cgi.header( { 'Location' => @conf.index } )
	    exit
	 end
      end
   end

   class AlbumPhotoConvert < AlbumPhotoEdit
      def initialize ( cgi, rhtml, conf )
	 super

	 if @cgi.valid?( 'rotate' ) then
	    unless @photo.rotate then
	       @photo.rotate = 0
	    end
	    if @photo.rotate == 'left' then
	       @photo.rotate += 90
	    else
	       @photo.rotate += -90
	    end
	 end

	 @photo.scale = @cgi['scale'][0].to_i if @cgi.valid?( 'scale' )

	 @photo = @photo.to_photofile( @conf )
	 @photo.do_convert
	 @photo.make_thumbnail

	 m = @cgi['photo'][0][0, 6]
	 d = @cgi['photo'][0][0, 8]
	 PStore::new( "#{@conf.data_path}#{m}.db" ).transaction do |db|
	    newday = Day::new( d )
	    db['p-album'][d].each_photo do |photo|
	       if photo.name == @cgi['photo'][0] then
		  photo = @photo.to_photo
	       end
	       newday << photo
	    end
	    db['p-album'][d] = newday
	 end
      end
   end
end
