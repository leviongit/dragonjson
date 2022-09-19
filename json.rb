module JSON
  class JSONKeyError < StandardError; end
  class JSONParseError < StandardError; end

  class << self
    def write(str, value, indent_size = 4)
      raise ArgumentError, "Top-level value must be either an Array or a Hash" unless value.is_a?(Array) || value.is_a?(Hash)

      write_value(str, value, 0, indent_size)
    end

    def read(str)
    end

    private

    def write_hash_inline(str, value, indent_depth, indent_size)
      raise ArgumentError, "value must be a Hash" unless value.is_a?(Hash)
      raise JSONKeyError, "Not all keys in hash are strings/symbols" unless value.keys.all? {
        String === _1 || Symbol === _1
      }

      return str << "{}" if value.keys.length == 0

      str << "{"

      value.each.with_index { |(k, v), i|
        str << "," if i != 0
        str << " #{k.to_s.inspect}: "
        write_value(str, v, indent_depth, indent_size)
      }

      str << " }"
    end

    def write_hash_block(str, value, indent_depth, indent_size)
      raise ArgumentError, "value must be a Hash" unless value.is_a?(Hash)
      raise JSONKeyError, "Not all keys in hash are strings/symbols" unless value.keys.all? {
        String === _1 || Symbol === _1
      }

      str << "{"

      value.each.with_index { |(k, v), i|
        str << "," if i != 0
        str << "\n#{" " * (indent_depth * indent_size)}#{k.to_s.inspect}: "
        write_value(str, v, indent_depth, indent_size)
      }

      str << "\n" + (" " * ((indent_depth - 1) * indent_size)) + "}"
    end

    def write_array_inline(str, value, indent_depth, indent_size)
      raise ArgumentError, "value must be an Array" unless value.is_a?(Array)

      return str << "[]" if value.length == 0

      str << "[ "

      value.each.with_index { |v, i|
        str << ", " if i != 0
        write_value(str, v, indent_depth, indent_size)
      }

      str << " ]"
    end

    def write_array_block(str, value, indent_depth, indent_size)
      raise ArgumentError, "value must be an Array" unless value.is_a?(Array)

      str << "[\n"

      value.each.with_index { |v, i|
        str << ",\n" if i != 0
        str << " " * (indent_size * indent_depth)
        write_value(str, v, indent_depth, indent_size)
      }

      str << "\n" + (" " * ((indent_depth - 1) * indent_size)) + "]"
    end

    def write_value(str, value, indent_depth = 0, indent_size = 4)
      case value
      when Hash
        if value.keys.length > 1 || value.any? { |_, v| v.is_a?(Array) || v.is_a?(Hash) }
          write_hash_block(str, value, indent_depth + 1, indent_size)
        else
          write_hash_inline(str, value, indent_depth + 1, indent_size)
        end
      when Array
        if value.length > 1 || value.any? { |_, v| v.is_a?(Array) || v.is_a?(Hash) }
          write_array_block(str, value, indent_depth + 1, indent_size)
        else
          write_array_inline(str, value, indent_depth + 1, indent_size)
        end
      when Float
        str << value.to_s
      when String
        str << value.inspect
      when Integer
        str << value.to_s
      when nil
        str << "null"
      when true
        str << "true"
      when false
        str << "false"
      else
        return value.write_json(str, indent_depth + 1, indent_size)
      end
    end

    def ws?(c)
      " " == c ||
      "\t" == c ||
      "\f" == c ||
      "\n" == c ||
      "\r" == c
    end

    def delim?(c)
      ws?(c) ||
      "," == c ||
      "}" == c ||
      "]" == c
    end

    def skip_ws(str)
      i = 0
      i += 1 while (ws?(str[i]))
      str.slice!(0, i)
    end

    def read_value(str)
    end

    def read_object(str)
    end

    def read_array(str)
    end

    def read_string(str)
      str.slice!(0) # skip the opening `"`

      ret = ""

      i = 0
      while (c = str[i]) != '"'
        i += 1
        if "\\" == c
          ret << str.slice!(0, i - 1)
          str.slice!(0) # skip the `\`
          i = 0

          ec = str.slice!(0) # get the escape char
          case ec
          # "\a", "\b", "\t", "\n", "\v", "\f", "\r", "\e", "\\", "\""
          when "a"
            ret << "\a"
          when "b"
            ret << "\b"
          when "t"
            ret << "\t"
          when "n"
            ret << "\n"
          when "v"
            ret << "\v"
          when "f"
            ret << "\f"
          when "r"
            ret << "\r"
          when "e"
            ret << "\e"
          when "\\"
            ret << "\\"
          when "\""
            ret << "\""
          end
        end
      end
      ret << str.slice!(0, i)

      ret
    end

    def read_number(str)
    end

    # used for bare words (i.e. `true`, `false`, and `null`);
    # raises an error if the word is not one of those three
    def read_value(str)
      i = 1
      i += 1 until (delim?(str[i]))
      w = str.slice!(0, i)
      case w
      when "true"
        true
      when "false"
        false
      when "null"
        nil
      else
        raise JSONParseError, "Unexpected bare word #{w.inspect}"
      end
    end
  end
end
