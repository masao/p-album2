#
# wiki_style.rb: WikiWiki style for tDiary 2.x format. $Revision$
#
# if you want to use this style, add @style into tdiary.conf below:
#
#    @style = 'Wiki'
#
# Copyright (C) 2003, TADA Tadashi <sho@spc.gr.jp>
# You can distribute this under GPL.
#
require 'p-album/wiki_parser'

module PhotoAlbum
   class WikiConverter
      def initialize
         @parser = WikiParser::new( :wikiname => false )
      end

      def to_html4( body )
         r = ""
         stat = nil
         @parser.parse( body ).each do |s|
            stat = s if s.class == Symbol
            case s

               # subtitle heading
            when :HS1
               r << "<h3>"
            when :HE1; r << "</h3>\n"

               # other headings
            when :HS2, :HS3, :HS4, :HS5; r << "<h#{s.to_s[2,1].to_i + 2}>"
            when :HE2, :HE3, :HE4, :HE5; r << "</h#{s.to_s[2,1].to_i + 2}>\n"

               # pargraph
            when :PS
               r << '<p>'
            when :PE; r << "</p>\n"

               # horizontal line
            when :RS; r << "<hr>\n"
            when :RE

               # blockquote
            when :QS; r << "<blockquote>\n"
            when :QE; r << "</blockquote>\n"

               # list
            when :US; r << "<ul>\n"
            when :UE; r << "</ul>\n"

               # ordered list
            when :OS; r << "<ol>\n"
            when :OE; r << "</ol>\n"

               # list item
            when :LS; r << "<li>"
            when :LE; r << "</li>\n"

               # definition list
            when :DS; r << "<dl>\n"
            when :DE; r << "</dl>\n"
            when :DTS; r << "<dt>"
            when :DTE; r << "</dt>"
            when :DDS; r << "<dd>"
            when :DDE; r << "</dd>\n"

               # formatted text
            when :FS; r << '<pre>'
            when :FE; r << "</pre>\n"

               # table
            when :TS; r << "<table border=\"1\">\n"
            when :TE; r << "</table>\n"
            when :TRS; r << "<tr>\n"
            when :TRE; r << "</tr>\n"
            when :TDS; r << "<td>"
            when :TDE; r << "</td>"

               # emphasis
            when :ES; r << "<em>"
            when :EE; r << "</em>"

               # strong
            when :SS; r << "<strong>"
            when :SE; r << "</strong>"

               # delete
            when :ZS; r << "<del>"
            when :ZE; r << "</del>"

               # Keyword
            when :KS; r << '<'
            when :KE; r << '>'

               # Plugin
            when :GS; r << '<%='
            when :GE; r << '%>'

               # URL
            when :XS; #r << '<a href="'
            when :XE; #r << '</a>'

            else
               s = CGI::escapeHTML( s ) unless stat == :GS
               case stat
               when :KS
                  r << keyword(s)
               when :XS
                  case s
                  when /^mailto:/
                     r << %Q[<a href="#{s}">#{s.sub( /^mailto:/, '' )}</a>]
                  when /\.(jpg|jpeg|png|gif)$/
                     r << %Q[<img src="#{s}" alt="#{File::basename( s )}">]
                  else
                     r << %Q[<a href="#{s}">#{s}</a>]
                  end
               else
                  r << s if s.class == String
               end
            end
         end
         r
      end

      private
      def keyword( s )
         r = ''
         if /^(\d{8}t\d{6}|\d{6}|\d{8}|\d{4}-\d{2}-\d{2}|\d{4}-\d{2}-\d{2}[t ]\d{2}:\d{2}:\d{2})$/i =~ s
            r << %Q[%=my '#{s}', '[#{s}]' %]
         elsif /\|/ =~ s
            k, u = s.split( /\|/, 2 )
            if /^(\d{4}|\d{6}|\d{8})[^\d]*?#?([pct]\d\d)?$/ =~ u then
               r << %Q[%=my '#{$1}#{$2}', '#{k}' %]
            elsif /:/ =~ u
               scheme, path = u.split( /:/, 2 )
               if /\A(?:http|https|ftp|mailto)\z/ =~ scheme
                  r << %Q[a href="#{u}">#{k}</a]
               else
                  r << %Q[%=kw '#{u}', '#{k}'%]
               end
            else
               r << %Q[a href="#{u}">#{k}</a]
            end
         else
            r << %Q[%=kw '#{s}' %]
         end
         r
      end
   end
end
