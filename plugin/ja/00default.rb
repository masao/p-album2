#
# ja/00default.rb: Japanese resources of 00default.rb.
#

#
# header
#
def title_tag
   r = "<title>#{CGI::escapeHTML( @conf.html_title )}"
   case @mode
   when /^photo/
      r = "<title>#{@photo.title}" if @photo and @photo.title and not @photo.title.empty?
   when 'month'
      r << " (#{@month.month[0,4]}-#{@month.month[4,2]})" if @date
   when 'edit'
      r << " (#{navi_edit})" if @date
   when 'conf'
      r << ' (����)'
   when 'saveconf'
      r << ' (���괰λ)'
   when 'search'
      r << ': ' << CGI::escapeHTML( @cgi.params['q'][0] )
   end
   r << '</title>'
end

#
# labels (normal)
#
def navi_index; '�ȥå�'; end
def navi_latest; '�ǿ�'; end
def navi_edit; '�Խ�'; end
def navi_update; '����'; end
def navi_total; '����'; end
def navi_back; '���'; end
def navi_preference; '����'; end
def navi_prev_month; '����'; end
def navi_next_month; '���'; end
def navi_prev_photo; '���μ̿�'; end
def navi_next_photo; '���μ̿�'; end

#
# labels (for mobile)
#
def mobile_navi_latest; '�ǿ�'; end
def mobile_navi_preference; '����'; end
def mobile_navi_prev_month; '��'; end
def mobile_navi_next_month; '��'; end

#
# preferences (resources)
#
add_conf_proc( 'default', '����' ) do
   saveconf_default
   <<-HTML
	<h3 class="subtitle">�ȥåץڡ���URL</h3>
	#{"<p>����Х�����̤Υ���ƥ�Ĥ�����л��ꤷ�ޤ���¸�ߤ��ʤ����ϲ������Ϥ��ʤ��Ƥ��ޤ��ޤ���</p>" unless @conf.mobile_agent?}
	<p><input name="index_page" value="#{@conf.index_page}" size="50"></p>
   HTML
end

add_conf_proc( 'header', '�إå����եå�' ) do
   saveconf_header

   <<-HTML
	<h3 class="subtitle">�����ȥ�</h3>
	#{"<p>HTML��&lt;title&gt;�����椪��ӡ���Х���ü������λ��Ȼ��˻Ȥ��륿���ȥ�Ǥ���HTML�����ϻȤ��ޤ���</p>" unless @conf.mobile_agent?}
	<p><input name="html_title" value="#{ CGI::escapeHTML @conf.html_title }" size="50"></p>
	<h3 class="subtitle">�إå�</h3>
	#{"<p>����Х����Ƭ�����������ʸ�Ϥ���ꤷ�ޤ���HTML�������Ȥ��ޤ�����&lt;%=navi%&gt;�פǡ��ʥӥ��������ܥ���������Ǥ��ޤ�(���줬�ʤ��ȹ������Ǥ��ʤ��ʤ�ΤǺ�����ʤ��褦�ˤ��Ƥ�������)���ޤ�����&lt;%=calendar%&gt;�פǥ��������������Ǥ��ޤ�������¾���Ƽ�ץ饰����򵭽ҤǤ��ޤ���</p>" unless @conf.mobile_agent?}
	<p><textarea name="header" cols="70" rows="10">#{ CGI::escapeHTML @conf.header }</textarea></p>
	<h3 class="subtitle">�եå�</h3>
	#{"<p>����Х�κǸ�����������ʸ�Ϥ���ꤷ�ޤ����إå���Ʊ�ͤ˻���Ǥ��ޤ���</p>" unless @conf.mobile_agent?}
	<p><textarea name="footer" cols="70" rows="10">#{ CGI::escapeHTML @conf.footer }</textarea></p>
	HTML
end

add_conf_proc( 'theme', '�ơ���' ) do
   saveconf_theme

   r = <<-HTML
	<h3 class="subtitle">�ơ��ޤλ���</h3>
	#{"<p>����Х�Υǥ������ơ��ޡ��⤷����CSS��ľ�����Ϥǻ��ꤷ�ޤ����ɥ�åץ������˥塼�����CSS���ꢪ�פ����򤷤����ˤϡ��������CSS��URL�����Ϥ��Ƥ���������</p>" unless @conf.mobile_agent?}
	<p>
	<select name="theme">
		<option value="">CSS���ꢪ</option>
	HTML
   @conf_theme_list.each do |theme|
      r << %Q|<option value="#{theme[0]}"#{if theme[0] == @conf.theme then " selected" end}>#{theme[1]}</option>|
   end
   r << <<-HTML
	</select>
	<input name="css" size="50" value="#{ @conf.css }">
	</p>
	#{"<p>�����ˤʤ��ơ��ޤ�<a href=\"http://www.tdiary.org/20021001.html\">�ơ��ޡ������꡼</a>��������Ǥ��ޤ���</p>" unless @conf.mobile_agent?}
	HTML
end
