#
# en/00default.rb: English resources of 00default.rb.
#

#
# header
#
def title_tag
   r = "<title>#{CGI::escapeHTML( @conf.html_title )}"
   case @mode
   when 'day', 'comment'
      r << " (#{account_title}#{@year}/#{@month}/#{@day})" if @date
   when 'month'
      r << " (#{account_title}#{@year}/#{@month})" if @date
   when 'edit'
      r << " (#{navi_edit} #{@year}/#{@month})" if @date
   when 'report'
      r << " (#{account_title}#{@year})" if @year
   when 'conf'
      r << ' (Preferences)'
   when 'saveconf'
      r << ' (Preferences Changed)'
   end
   r << '</title>'
end

#
# labels (normal)
#
def navi_index; 'Top'; end
def navi_latest; 'Latest'; end
def navi_edit; 'Edit'; end
def navi_update; 'Update'; end
def navi_total; 'Reckoning'; end
def navi_back; 'Back'; end
def navi_preference; 'Preference'; end
def navi_prev_month; 'Prev'; end
def navi_next_month; 'Next'; end

#
# labels (for mobile)
#
def mobile_navi_latest; 'Latest'; end
def mobile_navi_preference; 'Prefs'; end
def mobile_navi_prev_month; 'Prev'; end
def mobile_navi_next_month; 'Next'; end

#
# preferences (resources)
#
add_conf_proc( 'default', 'Basic' ) do
   saveconf_default
   <<-HTML
	<h3 class="subtitle">トップページURL</h3>
	#{"<p>アルバムよりも上位のコンテンツがあれば指定します。存在しない場合は何も入力しなくてかまいません。</p>" unless @conf.mobile_agent?}
	<p><input name="index_page" value="#{@conf.index_page}" size="50"></p>
	HTML
end

add_conf_proc( 'header', 'Header/Footer' ) do
   saveconf_header

   <<-HTML
	<h3 class="subtitle">タイトル</h3>
	#{"<p>HTMLの&lt;title&gt;タグ中および、モバイル端末からの参照時に使われるタイトルです。HTMLタグは使えません。</p>" unless @conf.mobile_agent?}
	<p><input name="html_title" value="#{ CGI::escapeHTML @conf.html_title }" size="50"></p>
	<h3 class="subtitle">ヘッダ</h3>
	#{"<p>アルバムの先頭に挿入される文章を指定します。HTMLタグが使えます。「&lt;%=navi%&gt;」で、ナビゲーションボタンを挿入できます(これがないと更新ができなくなるので削除しないようにしてください)。また、「&lt;%=calendar%&gt;」でカレンダーを挿入できます。その他、各種プラグインを記述できます。</p>" unless @conf.mobile_agent?}
	<p><textarea name="header" cols="70" rows="10">#{ CGI::escapeHTML @conf.header }</textarea></p>
	<h3 class="subtitle">フッタ</h3>
	#{"<p>アルバムの最後に挿入される文章を指定します。ヘッダと同様に指定できます。</p>" unless @conf.mobile_agent?}
	<p><textarea name="footer" cols="70" rows="10">#{ CGI::escapeHTML @conf.footer }</textarea></p>
	HTML
end

add_conf_proc( 'theme', 'Themes' ) do
   saveconf_theme

   r = <<-HTML
	<h3 class="subtitle">テーマの指定</h3>
	#{"<p>アルバムのデザインをテーマ、もしくはCSSの直接入力で指定します。ドロップダウンメニューから「CSS指定→」を選択した場合には、右の欄にCSSのURLを入力してください。</p>" unless @conf.mobile_agent?}
	<p>
	<select name="theme">
		<option value="">CSS指定→</option>
	HTML
   @conf_theme_list.each do |theme|
      r << %Q|<option value="#{theme[0]}"#{if theme[0] == @conf.theme then " selected" end}>#{theme[1]}</option>|
   end
   r << <<-HTML
	</select>
	<input name="css" size="50" value="#{ @conf.css }">
	</p>
	#{"<p>ここにないテーマは<a href=\"http://www.tdiary.org/20021001.html\">テーマ・ギャラリー</a>から入手できます。</p>" unless @conf.mobile_agent?}
	HTML
end
