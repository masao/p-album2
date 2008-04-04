def navi
   result = %Q[<div class="adminmenu">\n]
   result << %Q[<span class="adminmenu"><a href="#{@conf.index_page}">トップ</a></span>\n] unless @conf.index_page.empty?
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}#{anchor @prev_month}">&laquo;#{navi_prev_month}</a></span>\n] if @prev_month
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}#{anchor @prev_photo.name}"><img src="#{@prev_photo.thumbnail}" alt="#{navi_prev_photo}" title="#{navi_prev_photo}" #{html_imgsize(@prev_photo.thumbnail)}>&laquo;#{navi_prev_photo}</a></span>\n] if @prev_photo
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}">#{navi_latest}</a></span>\n] unless @mode == 'latest'
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}#{anchor @next_month}">#{navi_next_month}&raquo;</a></span>\n] if @next_month
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}#{anchor @next_photo.name}">#{navi_next_photo}&raquo;<img src="#{@next_photo.thumbnail}" alt="#{navi_next_photo}" title="#{navi_next_photo}" #{html_imgsize(@next_photo.thumbnail)}></a></span>\n] if @next_photo
   result << %Q[<span class="adminmenu"><a href="#{@conf.index}#{anchor @photo.name}">#{navi_back}</a></span>\n] if @mode =~ /^photo(edit|convert|original|save)$/
   menu_proc.each {|i| result << %Q[<span class="adminmenu">#{i}</span>\n]}
   result << %Q[</div>]
end
def navi_latest; '一覧'; end
