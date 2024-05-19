module LevisLibs
  module JSON
    class JSONParser
      class UnexpectedChar < StandardError
      end

      MAGIC_DISPATCH_TABLE = ([->(sself) {
                                 sself.__raise_unexpected
                               }] * 256).tap { |t|
        t[0x22] = ->(sself) {
          sself.__parse_string
        } # "\""
        read_num = ->(sself) {
          sself.__parse_number
        }
        t[0x2d] = read_num # "-"
        t[0x30] = read_num # "0"
        t[0x31] = read_num # "1"
        t[0x32] = read_num # "2"
        t[0x33] = read_num # "3"
        t[0x34] = read_num # "4"
        t[0x35] = read_num # "5"
        t[0x36] = read_num # "6"
        t[0x37] = read_num # "7"
        t[0x38] = read_num # "8"
        t[0x39] = read_num # "9"
        t[0x5b] = ->(sself) {
          sself.__advance_
          sself.__skip_ws
          return [] if sself.__match!("]")

          ary = sself.__parse_elements
          sself.__expect!("]")
          ary
        } # "["
        t[0x66] = ->(sself) {
          sself.__string("false")
          false
        } # "f"
        t[0x6e] = ->(sself) {
          sself.__string("null")
          nil
        } # "n"
        t[0x74] = ->(sself) {
          sself.__string("true")
          true
        } # "t"
        t[0x7b] = ->(sself) {
          sself.__advance_
          sself.__skip_ws
          return {} if sself.__match!("}")

          hsh = sself.__parse_members
          sself.__expect!("}")

          hsh = sself.__handle_parser_extensions(hsh)

          hsh
        } # "{"
      }.freeze

      def initialize(string, **kw)
        @len = string.size
        @str = string
        @idx = 0
        @c = string.getbyte(0)
        @col = 1
        @ln = 1
        @mct = MAGIC_DISPATCH_TABLE
        @kw = kw
      end

      def __raise_unexpected(_c = nil)
        raise UnexpectedChar, "Unexpected char '#{@c.chr}' at [#{@ln}:#{@col}]"
      end

      def __advance_
        @idx += 1
        @c = @str.getbyte(@idx)

        if @c == 10
          @ln += 1
          @col = 1
        else
          @col += 1
        end

        return nil
      end

      def __match!(c)
        return __matchb!(c.ord)
      end

      def __matchb!(b)
        if @c == b
          __advance_
          return true
        else
          return false
        end
      end

      def __matchb_any!(*cs)
        cs.any? { __matchb!(_1) }
      end

      def __matchb_none!(*cs)
        cs.none? { @c == _1 }
      end

      def __matchp!(p)
        if p[@c]
          __advance_
          return true
        else
          return false
        end
      end

      def __expect!(c)
        __match!(c) || raise(UnexpectedChar, "Expected #{c.inspect}, but got #{@c.chr.inspect} at #{@idx}, [#{@ln}:#{@col}]")
        return nil
      end

      def __expectb_!(b)
        __matchb!(b) || raise(UnexpectedChar, "Expected #{b.chr.inspect}, but got #{@c.chr.inspect} at #{@idx}, [#{@ln}:#{@col}]")
        return nil
      end

      def __expect_any!(*cs)
        cs.any? { __match!(_1) } ||
          raise(UnexpectedChar, "Expected any of #{cs.map {
                                                     _1.inspect
                                                   }.join(", ")}, but got #{@c.chr.inspect} at #{@idx}, [#{@ln}:#{@col}]")
        return nil
      end

      def __string(str)
        sl = str.length
        i = 0
        while sl > i
          if @c != str.getbyte(i)
            raise(UnexpectedChar, "Expected '#{str[i]}', got '#{@c.chr}' (in \"#{str}\" literal)")
          end

          __advance_
          i += 1
        end

        return nil
      end

      def __skip_ws
        __advance_ while @c == 0x20 || @c == 0x0a || @c == 0x09 || @c == 0x0d
        return
      end

      def __parse_element
        __skip_ws

        v = @mct[@c][self]

        __skip_ws

        return v
      end

      def __parse_value
        @mct[@c][self]
      end

      def __parse_number
        start = @idx
        __read_integer || raise(UnexpectedChar, "Expected the integer part of a numeric literal, got '#{@c.chr}', [#{@ln}:#{@col}]")
        iend = @idx

        __read_frac || raise(UnexpectedChar, "Expected nothing or the fractional part of a numeric literal, got '#{@c.chr}', [#{@ln}:#{@col}]")
        __read_exp || raise(UnexpectedChar, "Expected nothing or the exponent part of a numeric literal, got '#{@c.chr}' [#{@ln}:#{@col}]")
        nend = @idx

        if iend == nend
          @str[start..@idx].to_i
        else
          @str[start..@idx].to_f
        end
      end

      def __read_unsigned_integer
        __read_onenine_digits || __read_digit
      end

      def __read_integer
        __read_unsigned_integer || __matchb!(0x2d) && __read_unsigned_integer
      end

      def __read_frac
        if __matchb!(0x2e)
          __read_some_digits
        else
          true
        end
      end

      def __read_exp
        if __matchb_any!(0x65, 0x45)
          __read_sign
          __read_some_digits
        else
          true
        end
      end

      def __read_sign
        return __matchb_any!(0x2b, 0x2d)
      end

      def __read_digit
        return __matchb_any!(*(0x30..0x39))
      end

      def __read_onenine
        return __matchb_any!(*(0x31..0x39))
      end

      def __read_onenine_digits
        if __read_onenine
          next while __read_digit
          return true
        else
          return false
        end
      end

      def __read_many_digits
        next while __read_digit
        true
      end

      def __read_some_digits
        __read_many_digits if __read_digit
      end

      def __parse_characters
        str = ""
        next while __read_characters(str) || __read_escape(str)
        str
      end

      def __read_characters(str)
        start = @idx
        __advance_ until @c == 0x5c || @c == 0x22

        if start != @idx
          str << @str[start...@idx]
          return true
        else
          return false
        end
      end

      def __read_escape(str)
        return false unless __matchb!(0x5c)

        chr = @c.chr
        case chr
        when ?", ?\\, ?/
          str << chr
        when ?b
          str << "\b"
        when ?f
          str << "\f"
        when ?n
          str << "\n"
        when ?r
          str << "\r"
        when ?t
          str << "\t"
        when ?u
          unless $__ll_json_move_fast_and_break_things
            raise(NotImplementedError, "unicode escapes not yet implemented")
          end

          # acc = ""
          # 4.times {
          #   acc << __expect!(->(c) {
          #                       # i'll leave this "slow" for now
          #                       IS_DIGIT[c] || ("a".."f") === c || ("A".."F") === c
          #                     })
          # } # could be done better, i'm tired
          # str << acc.to_i(16)
        else
          raise(UnexpectedChar, "Unexpected escape #{@c.chr} at #{@idx}, [#{@ln}:#{@col}]")
        end

        __advance_
        return true
      end

      def __parse_elements
        ary = [__parse_element]
        ary << __parse_element while __matchb!(0x2c)

        ary
      end

      def __parse_string
        __expectb_!(0x22)
        str = __parse_characters
        __expectb_!(0x22)
        str
      end

      def __parse_members
        hsh = {}
        key, value = __parse_member
        hsh[key] = value
        while __matchb!(0x2c)
          key, value = __parse_member
          hsh[key] = value
        end

        hsh
      end

      def __parse_member
        __skip_ws

        key = __parse_string

        __skip_ws

        __expectb_!(0x3a)

        __skip_ws

        value = @mct[@c][self]

        __skip_ws

        return [@kw[:symbolize_keys] ? key.to_sym : key, value]
      end

      def __handle_symbol_extension(hsh)
        hsh[@kw[:symbolize_keys] ? :"@@jm:symbol" : "@@jm:symbol"]&.to_sym
      end

      def __handle_object_extension(hsh)
        symbolize_keys = @kw[:symbolize_keys]
        class_key = symbolize_keys ? :"@@jm:class" : "@@jm:class"

        classname = hsh[class_key]
        return if !classname

        klass = Object.const_get(classname)

        if !klass.respond_to?(:from_json)
          raise JSONUnsupportedType, "class #{classname} doesn't implement the `from_json` method"
        end

        value_key = symbolize_keys ? :"@@jm:value" : "@@jm:value"
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

      alias parse __parse_element
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
