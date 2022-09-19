module JSON
  class JSONKeyError < StandardError; end

  class << self
    def write(value, indent_size = 4)
      raise ArgumentError, "Top-level value must be either an Array or a Hash" unless Array === value || Hash === value

      str = ""

      write_value(str, value, 0, indent_size)

      str
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
  end
end
