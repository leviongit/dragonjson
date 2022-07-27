module JSON
  class JSONKeyError < StandardError; end

  class << self
    def write(stream, value, indent_size = 4)
      raise ArgumentError, "Top-level value must be either an Array or a Hash" unless value.is_a?(Array) || value.is_a?(Hash)

      write_value(stream, value, 0, indent_size)
    end

    private

    def write_hash_inline(stream, value, indent_depth, indent_size)
      raise ArgumentError, "value must be a Hash" unless value.is_a?(Hash)
      raise JSONKeyError, "Not all keys in hash are strings/symbols" unless value.keys.all? {
        _1.is_a?(String) || _1.is_a?(Symbol)
      }

      return stream << "{}" if value.keys.length == 0

      stream << "{"

      value.each.with_index { |(k, v), i|
        stream << "," if i != 0
        stream << " #{k.to_s.inspect}: "
        write_value(stream, v, indent_depth, indent_size)
      }

      stream << " }"
    end

    def write_hash_block(stream, value, indent_depth, indent_size)
      raise ArgumentError, "value must be a Hash" unless value.is_a?(Hash)
      raise JSONKeyError, "Not all keys in hash are strings/symbols" unless value.keys.all? {
        _1.is_a?(String) || _1.is_a?(Symbol)
      }

      stream << "{"

      value.each.with_index { |(k, v), i|
        stream << "," if i != 0
        stream << "\n#{" " * (indent_depth * indent_size)}#{k.to_s.inspect}: "
        write_value(stream, v, indent_depth, indent_size)
      }

      stream << "\n" + (" " * ((indent_depth - 1) * indent_size)) + "}"
    end

    def write_array_inline(stream, value, indent_depth, indent_size)
      raise ArgumentError, "value must be an Array" unless value.is_a?(Array)

      return stream << "[]" if value.length == 0

      stream << "[ "

      value.each.with_index { |v, i|
        stream << ", " if i != 0
        write_value(stream, v, indent_depth, indent_size)
      }

      stream << " ]"
    end

    def write_array_block(stream, value, indent_depth, indent_size)
      raise ArgumentError, "value must be an Array" unless value.is_a?(Array)

      stream << "[\n"

      value.each.with_index { |v, i|
        stream << ",\n" if i != 0
        stream << " " * (indent_size * indent_depth)
        write_value(stream, v, indent_depth, indent_size)
      }

      stream << "\n" + (" " * ((indent_depth - 1) * indent_size)) + "]"
    end

    def write_value(stream, value, indent_depth = 0, indent_size = 4)
      case value
      when Hash
        if value.keys.length > 1 || value.any? { |_, v| v.is_a?(Array) || v.is_a?(Hash) }
          write_hash_block(stream, value, indent_depth + 1, indent_size)
        else
          write_hash_inline(stream, value, indent_depth + 1, indent_size)
        end
      when Array
        if value.length > 1 || value.any? { |_, v| v.is_a?(Array) || v.is_a?(Hash) }
          write_array_block(stream, value, indent_depth + 1, indent_size)
        else
          write_array_inline(stream, value, indent_depth + 1, indent_size)
        end
      when Float
        stream << value.to_s
      when String
        stream << value.inspect
      when Integer
        stream << value.to_s
      when nil
        stream << "null"
      when true
        stream << "true"
      when false
        stream << "false"
      end
    end
  end
end
