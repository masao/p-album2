# Tiny eRuby --- ERB2
# Copyright (c) 1999-2000,2002,2003 Masatoshi SEKI 
# You can redistribute it and/or modify it under the same terms as Ruby.

class ERB
  Revision = '$Date$' 	#'

  def self.version
    "erb.rb [2.0.2 #{ERB::Revision.split[1]}]"
  end
end

# ERB::Compiler
class ERB
  class Compiler
    class ParcentLine
      def initialize(compiler, str)
	@compiler = compiler
	@line = str
      end

      def expand(list)
	str = @line.dup
	str[0] = ''
	if /^%%/ === @line
	  list.unshift("\n")
	  list.unshift(str)
	else
	  list.unshift('%>')
	  list.unshift(str)
	  list.unshift('<%')
	end
	list
      end
      
      def expand_in_script(list)
	ary = []
	@compiler.push_line(ary, @line)
	ary.reverse_each do |x|
	  list.unshift(x)
	end
      end
    end

    ERbTag = "<%% %%> <%= <%# <% %>".split
    def is_erb_tag?(s)
      ERbTag.member?(s)
    end

    SplitRegexp = /(<%%)|(%%>)|(<%=)|(<%#)|(<%)|(%>)|(\n)/

    def prepare_trim_mode(mode)
      case mode
      when 1
	return [false, '>']
      when 2
	return [false, '<>']
      when 0
	return [false, nil]
      when String
	perc = mode.include?('%')
	if mode.include?('<>')
	  return [perc, '<>']
	elsif mode.include?('>')
	  return [perc, '>']
	else
	  [perc, nil]
	end
      else
	return [false, nil]
      end
    end

    def pre_compile(s)
      re = SplitRegexp
      if @trim_mode.nil? && !@perc
	list = s.split(re)
      else
	list = []
	has_cr = (s[-1] == ?\n)
	s.each do |line|
	  line = line.chomp
	  if @perc && (/^%/ =~ line)
	    list.push(ParcentLine.new(self, line))
	  else
	    push_line(list, line)
	  end
	end
	list.pop if list[-1] == "\n" && !has_cr
      end
      list
    end

    def push_line(list, line)
      re = SplitRegexp
      line = line.split(re)
      line.shift if line[0]==''
      list.concat(line)
      unless ((@trim_mode == '>' && line[-1] == '%>') ||
	      (@trim_mode == '<>' && (is_erb_tag?(line[0])) && 
	       line[-1] == '%>'))
	list.push("\n") 
      end
    end

    def compile(s)
      list = pre_compile(s)
      cmd = []
      cmd.concat(@pre_cmd)

      stag = nil
      content = []
      while (token = list.shift) 
	if token == '<%%'
	  token = '<'
	  list.unshift '%'
	elsif token == '%%>'
	  token = '%'
	  list.unshift '>'
	end
	if stag.nil?
	  if ['<%', '<%=', '<%#'].include?(token)
	    stag = token
	    str = content.join('')
	    if str.size > 0
	      cmd.push("#{@put_cmd} #{str.dump}")
	    end
	    content = []
	  elsif token == "\n"
	    content.push("\n")
	    cmd.push("#{@put_cmd} #{content.join('').dump}")
	    cmd.push(:cr)
	    content = []
	  elsif ParcentLine === token
	    token.expand(list)
	    next
	  else
	    content.push(token)
	  end
	else
	  if token == '%>'
	    case stag
	    when '<%'
	      str = content.join('')
	      if str[-1] == ?\n
		str.chop!
		cmd.push(str)
		cmd.push(:cr)
	      else
		cmd.push(str)
	      end
	    when '<%='
	      cmd.push("#{@put_cmd}((#{content.join('')}).to_s)")
	    when '<%#'
	      # cmd.push("# #{content.dump}")
	    end
	    stag = nil
	    content = []
	  elsif ParcentLine === token
	    token.expand_in_script(list)
	    next
	  else
	    content.push(token)
	  end
	end
      end
      if content.size > 0
	cmd.push("#{@put_cmd} #{content.join('').dump}")
      end
      cmd.push(:cr)
      cmd.concat(@post_cmd)

      ary = []
      cmd.each do |x|
	if x == :cr
	  ary.pop
	  ary.push("\n")
	else
	  ary.push(x)
	  ary.push('; ')
	end
      end
      ary.join('')
    end

    def initialize(trim_mode)
      @perc, @trim_mode = prepare_trim_mode(trim_mode)
      @put_cmd = 'print'
      @pre_cmd = []
      @post_cmd = []
    end

    attr_accessor(:put_cmd)
    attr_accessor(:pre_cmd)
    attr_accessor(:post_cmd)
  end
end

# ERB
class ERB
  def initialize(str, safe_level=nil, trim_mode=nil, eoutvar='_erbout')
    @safe_level = safe_level
    compiler = ERB::Compiler.new(trim_mode)
    set_eoutvar(compiler, eoutvar)
    @src = compiler.compile(str)
  end
  attr :src

  def set_eoutvar(compiler, eoutvar = '_erbout')
    compiler.put_cmd = "#{eoutvar}.concat"

    cmd = []
    cmd.push "#{eoutvar} = ''"
    
    compiler.pre_cmd = cmd

    cmd = []
    cmd.push(eoutvar)

    compiler.post_cmd = cmd
  end

  def run(b=TOPLEVEL_BINDING)
    print self.result(b)
  end

  def result(b=TOPLEVEL_BINDING)
    if @safe_level
      th = Thread.start { 
	$SAFE = @safe_level
	eval(@src, b)
      }
      return th.value
    else
      return eval(@src, b)
    end
  end

  def def_method(mod, methodname, fname='(ERB)')
    mod.module_eval("def #{methodname}\n" + self.src + "\nend\n", fname, 0)
  end

  def def_module(methodname='erb')
    mod = Module.new
    def_method(mod, methodname)
    mod
  end

  def def_class(superklass=Object, methodname='result')
    cls = Class.new(superklass)
    def_method(cls, methodname)
    cls
  end
end

# ERB::Util
class ERB
  module Util
    public
    def html_escape(s)
      s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
    end
    alias h html_escape
    
    def url_encode(s)
      s.to_s.gsub(/[^a-zA-Z0-9_\-.]/n){ sprintf("%%%02X", $&.unpack("C")[0]) }
    end
    alias u url_encode
  end
end

# ERB::DefMethod
class ERB
  module DefMethod
    public
    def def_erb_method(methodname, erb)
      if erb.kind_of? String
	fname = erb
	File.open(fname) {|f| erb = ERB.new(f.read) }
      end
      erb.def_method(self, methodname, fname)
    end
    module_function :def_erb_method
  end
end
