#
# make navigation buttons
#
def navi
   result = %Q[<div class="adminmenu">\n]
   result << %Q[<span class="adminmenu"><a href="#{@conf.index_page}">¥È¥Ã¥×</a></span>\n] unless @conf.index_page.empty?
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}?date=#{@prev_month}">&laquo;#{navi_prev_month}</a></span>\n] if @prev_month
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}?photo=#{@prev_photo}">&laquo;#{navi_prev_photo}</a></span>\n] if @prev_photo
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}">#{navi_latest}</a></span>\n] unless @mode == 'latest'
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}?date=#{@next_month}">#{navi_next_month}&raquo;</a></span>\n] if @next_month
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}?photo=#{@next_photo}">#{navi_next_photo}&raquo;</a></span>\n] if @next_photo
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}?photo=#{@photo.name}">#{navi_back}</a></span>\n] if @mode =~ /^photo(edit|convert|original|save)$/
   result << %Q[<span class="adminmenu"><a href="#{@conf.update}?photo=#{@photo.name}">#{navi_edit}</a></span>\n] if @mode == 'photo'
   menu_proc.each {|i| result << %Q[<span class="adminmenu">#{i}</span>\n]}
   result << %Q[<span class="adminmenu"><a href="#{@conf.update}">#{navi_update}</a></span>\n] unless /^update|photo.*$/ =~ @mode
   result << %Q[<span class="adminmenu"><a href="#{@conf.update}?conf=default">#{navi_preference}</a></span>\n] unless /^latest|month|conf|photo$/ =~ @mode
   result << %Q[</div>]
end

def mobile_navi
   calc_links
   result = []
   result << %Q[<a href="#{@conf.index}?date=#{@prev_month}" accesskey="1">[1]#{mobile_navi_prev_month}</a>] if @mode == 'month'
   result << %Q[<a href="#{@conf.index}" accesskey="2">[2]#{mobile_navi_latest}</a>]
   result << %Q[<a href="#{@conf.index}?date=#{@next_month}" accesskey="3">[3]#{mobile_navi_next_month}</a>] if @mode == 'month'
   result << %Q[<a href="#{@conf.update}?conf=default" accesskey="0">[0]#{mobile_navi_preference}</a>]
   result.join('|')
end

#
# make calendar
#
def calendar
   result = %Q[<div class="calendar">\n]
   @years.keys.sort.each do |year|
      result << %Q[<div class="year">#{year} |]
      "01".upto( "12" ) do |m|
	 if @years[year].include?( "#{year}#{m}" ) then
	    result << %Q[<a href="#{@conf.index}?date=#{year}#{m}">#{m}</a>|]
	 else
	    result << %Q[#{m}|]
	 end
      end
      result << "</div>\n"
   end
   result << "</div>"
end

def total_photo
   @all_photos.size
end

def total_photo_size
   total = 0
   @all_photos.collect{|p| "#{@conf.images_dir}#{p}#{PhotoAlbum::PhotoFile::EXT}".untaint }.each do |f|
      total += FileTest::size( f )
   end
   total
end

#
# define DOCTYPE
#
def doctype
   %Q[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">]
end

#
# default HTML header
#
add_header_proc do
   calc_links
   r = <<-HEADER
	<meta http-equiv="content-type" content="text/html; charset=#{charset}">
	<meta name="generator" content="p-album #{PHOTOALBUM_VERSION}">
	#{content_script_type}
	#{index_page_tag}
	#{css_tag.chomp}
	#{title_tag.chomp}
	HEADER
   r
end

def calc_links
   if @mode == 'month' then
      m = @date[0, 6]
      month_list = @years.keys.sort.collect{|y| @years[y]}.flatten
      if idx = month_list.index( m )
         @prev_month = month_list[ idx - 1 ] unless idx == 0
         @next_month = month_list[ idx + 1 ]
      end
   end

   if @photo then
      m = @photo.name[0, 6]
      idx = @all_photos.index( @photo.name )
      unless idx == 0 then
	 @prev_photo = @all_photos[ idx - 1 ]
      end
      unless idx == @all_photos.size - 1 then
	 @next_photo = @all_photos[ idx + 1 ]
      end
   end
end

def charset
   if @conf.mobile_agent? then
      @conf.mobile_encoding
   else
      @conf.encoding
   end
end

def content_script_type
   %q[<meta http-equiv="content-script-type" content="text/javascript; charset=#{charset}">]
end

def index_page_tag
   result = ''
   if @conf.index_page and @conf.index_page.size > 0 then
      result << %Q[<link rel="start" title="#{navi_index}" href="#{@conf.index_page}">\n\t]
   end

   if @prev_month then
      result << %Q[<link rel="prev" title="#{navi_prev_month}" href="#{@conf.index}?date=#{@prev_month}">\n\t]
   end
   if @next_month then
      result << %Q[<link rel="next" title="#{navi_next_month}" href="#{@conf.index}?date=#{@next_month}">\n\t]
   end

   if @prev_photo then
      result << %Q[<link rel="prev" title="#{navi_prev_photo}" href="#{@conf.index}?photo=#{@prev_photo}">\n\t]
   end
   if @next_photo then
      result << %Q[<link rel="next" title="#{navi_next_photo}" href="#{@conf.index}?photo=#{@next_photo}">\n\t]
   end

   result << %Q[<link rel="last" title="#{navi_latest}" href="#{@conf.index}">\n\t]

   result.strip
end

def theme_url; 'theme'; end

def css_tag
   if @conf.theme and @conf.theme.length > 0 then
      css = "#{theme_url}/#{@conf.theme}/#{@conf.theme}.css"
      title = css
   else
      css = @conf.css
   end
   title = CGI::escapeHTML( File::basename( css, '.css' ) )
   <<-CSS
   <meta http-equiv="content-style-type" content="text/css">
   <link rel="stylesheet" href="#{theme_url}/base.css" type="text/css" media="all">
   <link rel="stylesheet" href="#{css}" title="#{title}" type="text/css" media="all">
   CSS
end

#
# other resources
#

#
# preferences
#

# basic (default)
def saveconf_default
   if @mode == 'saveconf' then
      @conf.index_page = @cgi.params['index_page'][0]
   end
end

# header/footer (header)
def saveconf_header
   if @mode == 'saveconf' then
      @conf.html_title = @conf.to_native( @cgi.params['html_title'][0] )
      @conf.header = @conf.to_native( @cgi.params['header'][0] ).gsub( /\r\n/, "\n" ).gsub( /\r/, '' ).sub( /\n+\z/, '' )
      @conf.footer = @conf.to_native( @cgi.params['footer'][0] ).gsub( /\r\n/, "\n" ).gsub( /\r/, '' ).sub( /\n+\z/, '' )
   end
end

# themes
def saveconf_theme
   if @mode == 'saveconf' then
      @conf.theme = @cgi.params['theme'][0]
      @conf.css = @cgi.params['css'][0]
   end
end

if @mode =~ /^(conf|saveconf)$/ then
   @conf_theme_list = []
   Dir::glob( "#{PhotoAlbum::PATH}/theme/*" ).sort.each do |dir|
      theme = dir.sub( %r[.*/theme/], '')
      next unless FileTest::file?( "#{dir}/#{theme}.css".untaint )
      name = theme.split( /_/ ).collect{|s| s.capitalize}.join( ' ' )
      @conf_theme_list << [theme,name]
   end
end
