module LevisLibs
  module JSON
    class JSONParser
      class UnexpectedChar < StandardError
      end

      MAGIC_DISPATCH_TABLE = [:__raise_unexpected] * 256
      MAGIC_DISPATCH_TABLE['"'.ord] = :__parse_string
      MAGIC_DISPATCH_TABLE['-'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['0'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['1'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['2'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['3'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['4'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['5'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['6'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['7'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['8'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['9'.ord] = :__parse_number
      MAGIC_DISPATCH_TABLE['['.ord] = :__parse_array
      MAGIC_DISPATCH_TABLE['f'.ord] = :__parse_false
      MAGIC_DISPATCH_TABLE['n'.ord] = :__parse_null
      MAGIC_DISPATCH_TABLE['t'.ord] = :__parse_true
      MAGIC_DISPATCH_TABLE['{'.ord] = :__parse_hash
      MAGIC_DISPATCH_TABLE.freeze

      def initialize(string, symbolize_keys: false, **kw)
        @str = string
        @idx = 0
        @c = string.getbyte(0)

        @symbolize_keys = symbolize_keys
        @kw = kw
      end

      def __failed(msg)
        line = @str.slice(0, @idx).count("\n") + 1
        column = @idx - (@str.rindex("\n", (@idx - 1).clamp(0, @idx)) || -1)
        raise UnexpectedChar, "#{msg} at [#{line}:#{column}]"
      end

      def __raise_unexpected
        __failed "Unexpected char '#{@c.chr}'"
      end

      def __advance
        __failed "Unexpected EOF" unless @c
        @c = @str.getbyte(@idx += 1)
        return true
      end

      def __matchb!(b)
        __advance if @c == b
      end

      def __expectb!(b)
        return __advance if @c == b
        __failed "Expected #{b.chr.inspect}, but got #{@c&.chr&.inspect || "EOF"}"
      end

      def __string(str)
        sl = str.length
        i = 0
        while sl > i
          if @c != str.getbyte(i)
            __failed "Expected '#{str[i]}', got '#{@c&.chr || "EOF"}' (in \"#{str}\" literal)"
          end

          __advance
          i += 1
        end

        return nil
      end

      def __skip_ws
        __advance while @c == 0x20 || @c == 0x0A || @c == 0x09 || @c == 0x0D
      end

      def __parse_array
        __advance
        __skip_ws

        array = []

        unless __matchb!(0x5d) # 0x5d is closing square bracket
          while true
            array << __parse_element
            __skip_ws
            break unless __matchb!(0x2c) # 0x2c is comma
          end

          __expectb!(0x5d) # 0x5d is closing square bracket
        end

        return array
      end

      def __parse_hash
        __advance
        __skip_ws

        hash = {}

        unless __matchb!(0x7d) # 0x7d is closing curly brace
          while true
            __parse_member(hash)
            __skip_ws
            break unless __matchb!(0x2c) # 0x2c is comma
          end

          __expectb!(0x7d) # 0x7d is closing curly brace

          hash = __handle_parser_extensions(hash)
        end

        return hash
      end

      def parse
        __skip_ws
        return nil if @c.nil?
        v = __parse_value
        __skip_ws
        __failed("expected EOF got #{@c.chr.inspect}") if @c
        v
      end

      def __parse_element
        __skip_ws
        return nil if @c.nil?
        __parse_value
      end

      def __parse_null
        __string("null")
        return nil
      end

      def __parse_true
        __string("true")
        return true
      end

      def __parse_false
        __string("false")
        return false
      end

      def __parse_value
        __failed "Unexpected EOF" unless @c
        send(MAGIC_DISPATCH_TABLE[@c])
      end

      def __parse_number
        start = @idx
        __read_integer || __failed("Expected the integer part of a numeric literal, got '#{@c&.chr || '\0'}'")
        iend = @idx

        __read_frac || __failed("Expected nothing or the fractional part of a numeric literal, got '#{@c&.chr || '\0'}'")
        __read_exp || __failed("Expected nothing or the exponent part of a numeric literal, got '#{@c&.chr || '\0'}'")
        nend = @idx

        if iend == nend
          @str[start...nend].to_i
        else
          @str[start...nend].to_f
        end
      end

      def __read_unsigned_integer
        __read_onenine_digits || __read_digit
      end

      def __read_integer
        __matchb!(0x2d) # 0x2d is minus
        __read_unsigned_integer
      end

      def __read_frac
        return true unless __matchb!(0x2e) # 0x2e is period
        __read_some_digits
      end

      def __read_exp
        return true unless @c == 0x65 || @c == 0x45 # 0x65 is e, 0x45 is E
        __advance
        __read_sign
        __read_some_digits
      end

      def __read_sign
        __advance if @c == 0x2b || @c == 0x2d # 0x2b is plus, 0x2d is minus
      end

      def __read_digit
        __advance if @c && @c >= 0x30 && @c <= 0x39 # 0-9
      end

      def __read_onenine
        __advance if @c && @c >= 0x31 && @c <= 0x39 # 1-9
      end

      def __read_onenine_digits
        __read_many_digits if __read_onenine
      end

      def __read_some_digits
        __read_many_digits if __read_digit
      end

      def __read_many_digits
        nil while __read_digit
        return true
      end

      def __parse_characters
        str = ""
        nil while __read_characters(str) || __read_escape(str)
        str
      end

      def __read_characters(str)
        start = @idx
        __advance until @c == 0x5c || @c == 0x22 # 0x5c is backslash, 0x22 is double quote

        if start != @idx
          str << @str[start...@idx]
          return true
        end
      end

      def __read_escape(str)
        return false unless __matchb!(0x5c) # 0x5c is backslash

        case @c
        when 0x22, 0x5c, 0x2f # 0x22 is double quote, 0x5c is backslash, 0x2f is forward slash
          str << chr
        when 0x62 # b
          str << 0x08 # bell
        when 0x66 # f
          str << 0x0c # form feed
        when 0x6e # n
          str << 0x0a # new line
        when 0x72 # r
          str << 0x0d # carriage ret
        when 0x74 # t
          str << 0x09 # horizontal tab
        when 0x75 # u
          __failed("unicode escapes not yet reimplemented")
        when nil
          __failed("Unexpected EOF")
        else
          __failed("unexpected escape #{@c.chr}")
        end

        return __advance
      end

      def __parse_string
        __expectb!(0x22) # 0x22 is double quote
        str = __parse_characters
        __expectb!(0x22) # 0x22 is double quote
        return str
      end

      def __parse_member(hash)
        __skip_ws
        key = __parse_string
        key = key.to_sym if @symbolize_keys
        __skip_ws
        __expectb!(0x3a) # 0x3a is colon
        __skip_ws
        hash[key] = __parse_value

        return nil
      end

      def __handle_symbol_extension(hsh)
        hsh[@symbolize_keys ? :"@@jm:symbol" : "@@jm:symbol"]&.to_sym
      end

      def __handle_object_extension(hsh)
        class_key = @symbolize_keys ? :"@@jm:class" : "@@jm:class"

        classname = hsh[class_key]
        return if !classname

        klass = Object.const_get(classname)

        if !klass.respond_to?(:from_json)
          raise JSONUnsupportedType, "class #{classname} doesn't implement the `from_json` method"
        end

        value_key = @symbolize_keys ? :"@@jm:value" : "@@jm:value"
        return if !hsh.key?(value_key)

        value = hsh[value_key]

        klass.from_json(value)
      end

      def __handle_parser_extensions(hsh)
        return hsh unless @kw[:extensions]

        (if hsh.size == 1
           __handle_symbol_extension(hsh)
         elsif hsh.size == 2
           __handle_object_extension(hsh)
         end) ||
          hsh
      end
    end

    class JSONKeyError < StandardError
    end

    class JSONUnsupportedType < StandardError
    end

    class << self
      def write(value, indent_size = 4, **kw)
        if !(Array === value || Hash === value)
          raise(
            ArgumentError,
            "Top-level value must be either an Array or a Hash"
          )
        end

        value.to_json(
          indent_depth: 0,
          indent_size: indent_size,
          minify: indent_size == -1,
          **kw
        )
      end

      def parse(
        string,
        **kw
      )
        JSONParser.new(string, **kw).parse
      end
    end

    class ::Hash
      def to_json(
        indent_depth: 0,
        indent_size: 4,
        minify: false,
        space_in_empty: true,
        **kw
      )
        raise JSONKeyError, "Not all keys are instances of `String` or `Symbol`" if !keys.all? { String === _1 || Symbol === _1 }

        space_in_empty &&= !minify

        return "{#{space_in_empty ? " " : ""}}" if self.length == 0

        space = minify ? "" : " "
        pairs = self.map { |k, v| "#{k.to_json(extensions: false)}:#{space}#{v.to_json(indent_depth: indent_depth + 1, indent_size: indent_size, minify: minify, space_in_empty: space_in_empty, **kw)}" }

        if minify
          "{#{pairs.join(",")}}"
        else
          indent = " " * (indent_depth * indent_size)
          indent_p1 = " " * ((indent_depth + 1) * indent_size)
          "{\n#{indent_p1}#{pairs.join(",\n#{indent_p1}")}\n#{indent}}"
        end
      end
    end

    class ::Array
      def to_json(
        indent_depth: 0,
        indent_size: 4,
        minify: false,
        space_in_empty: true,
        **kw
      )
        space_in_empty &&= !minify

        return "[#{space_in_empty ? " " : ""}]" if self.length == 0

        values = self.map { |v|
          v.to_json(
            indent_depth: indent_depth + 1,
            indent_size: indent_size,
            minify: minify,
            space_in_empty: space_in_empty,
            **kw
          )
        }

        if minify
          "[#{values.join(",")}]"
        else
          indent = " " * (indent_depth * indent_size)
          indent_p1 = " " * ((indent_depth + 1) * indent_size)
          "[\n#{indent_p1}#{values.join(",\n#{indent_p1}")}\n#{indent}]"
        end
      end
    end

    class ::Numeric
      def to_json(
        **_kw
      )
        self.inspect
      end
    end

    class ::TrueClass
      def to_json(
        **_kw
      )
        "true"
      end
    end

    class ::FalseClass
      def to_json(
        **_kw
      )
        "false"
      end
    end

    class ::NilClass
      def to_json(
        **_kw
      )
        "null"
      end
    end

    class ::String
      def to_json(
        **_kw
      )
        if $__ll_json_move_fast_and_break_things
          return "\"\"" if self.length == 0

          # needs_escaping = -> (c) { c == "\"" || c == "\\" }
          # is_not_printable = -> (c) { ("\x00".."\x1f") === c }

          acc = "\""

          bi = 0
          ei = 0
          l = self.length

          while ei < l
            cc = getbyte(ei)
            needs_escaping_v = cc == 0x22 || cc == 0x5c
            is_not_printable_v = cc < 0x20 || cc > 0x7f
            next ei += 1 unless needs_escaping_v || is_not_printable_v

            acc << self[bi...ei]
            bi = ei

            if needs_escaping_v
              bi += 1
              ei += 1
              acc << "\\" << cc
              next
            end

            next unless is_not_printable_v

            bi += 1
            ei += 1
            if cc == 8
              acc << "\\b"
            elsif cc == 9
              acc << "\\t"
            elsif cc == 10
              acc << "\\n"
            elsif cc == 12
              acc << "\\f"
            elsif cc == 13
              acc << "\\r"
            else
              acc << "\\u" << cc.to_s(16).rjust(4, "0")
            end

            next
          end

          acc << self[bi...ei]

          acc << "\""
          acc
        else
          self.inspect
        end
      end
    end

    class ::Symbol
      def to_json(
        extensions: false,
        symbolize_keys: false,
        **kw
      )
        if extensions
          {:"@@jm:symbol" => self.to_s}.to_json(**kw, minify: true)
        else
          self.to_s.inspect
        end
      end
    end

    class ::Object
      def to_json(
        value: nil,
        **kw
      )
        # the self is here for me to keep my sanity
        if self.method(__method__).owner == Object
          raise JSONUnsupportedType, "Object of class #{self.class.name} cannot be serialized to JSON"
        end

        {
          "@@jm:class" => self.class.name,
          "@@jm:value" => value
        }.to_json(**kw)
      end
    end
  end

  class ::GTK::Runtime
    def write_json(filename, hash_or_array, indent_size = 4, **kw)
      write_file(filename, hash_or_array.to_json(indent_size: indent_size, minify: indent_size == -1, **kw))
    end
  end
end
