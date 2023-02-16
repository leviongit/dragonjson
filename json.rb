module LevisLibs
  module JSON
    class JSONKeyError < StandardError; end
    class JSONUnsupportedType < StandardError; end

    class << self
      def write(value, indent_size = 4)
        raise ArgumentError, "Top-level value must be either an Array or a Hash" unless Array === value || Hash === value

        str = ""
        write_value(str, value, 0, -1)

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
        # case value
        # when Hash
        #   if (value.keys.length > 1 || value.any? { |_, v| v.is_a?(Array) || v.is_a?(Hash) }) && (indent_size != 0)
        #     write_hash_block(str, value, indent_depth + 1, indent_size)
        #   else
        #     write_hash_inline(str, value, indent_depth + 1, indent_size)
        #   end
        # when Array
        #   if (value.length > 1 || value.any? { |_, v| v.is_a?(Array) || v.is_a?(Hash) }) && (indent_size != 0)
        #     write_array_block(str, value, indent_depth + 1, indent_size)
        #   else
        #     write_array_inline(str, value, indent_depth + 1, indent_size)
        #   end
        # when Float
        #   str << value.to_s
        # when String
        #   str << value.inspect
        # when Integer
        #   str << value.to_s
        # when nil
        #   str << "null"
        # when true
        #   str << "true"
        # when false
        #   str << "false"
        # else
        #   return value.write_json(str, indent_depth + 1, indent_size)
        # end
        str << value.to_json(block: true,
                             indent_depth: indent_depth,
                             indent_size: indent_size,
                             minify: p(indent_size == -1))
      end
    end

    class ::Hash
      def to_json(block: false,
                  indent_depth: 0,
                  indent_size: 4,
                  minify: false)
        raise JSONKeyError, "Not all keys are instances of `String` or `Symbol`" if !keys.all? { String === _1 || Symbol === _1 }

        block &&= !minify

        if !block
          space = minify ? "" : " "
          "{#{self.map { |k, v| "#{k.to_json}:#{space}#{v.to_json(minify: minify)}" }.join(",#{space}")}}"
        else
          todo!()
        end
      end
    end

    class ::Array
      def to_json(block: false,
                  indent_depth: 0,
                  indent_size: 4,
                  minify: false)
        block &&= !minify

        if !block
          space = minify ? "" : " "
          "[#{self.map { |v| v.to_json(minify: minify) }.join(",#{space}")}]"
        else
          todo!()
        end
      end
    end

    class ::Numeric
      def to_json(block: false,
                  indent_depth: 0,
                  indent_size: 4,
                  minify: false)
        self.inspect
      end
    end

    class ::TrueClass
      def to_json(block: false,
                  indent_depth: 0,
                  indent_size: 4,
                  minify: false)
        "true"
      end
    end

    class ::FalseClass
      def to_json(block: false,
                  indent_depth: 0,
                  indent_size: 4,
                  minify: false)
        "false"
      end
    end

    class ::NilClass
      def to_json(block: false,
                  indent_depth: 0,
                  indent_size: 4,
                  minify: false)
        "null"
      end
    end

    class ::String
      def to_json(block: false,
                  indent_depth: 0,
                  indent_size: 4,
                  minify: false)
        self.inspect
      end
    end

    class ::Symbol
      def to_json(block: false,
                  indent_depth: 0,
                  indent_size: 4,
                  minify: false)
        self.to_s.inspect
      end
    end

    class ::Object
      def to_json(block: false,
                  indent_depth: 0,
                  indent_size: 4,
                  minify: false)
        raise JSONUnsupportedType, "Object of class #{self.class.name} cannot be serialized to JSON"
      end
    end
  end

  class ::GTK::Runtime
    def write_json(filename, hash_or_array, indent_size = 4)
      write_file(filename, JSON::write(hash_or_array, indent_size))
    end
  end
end
