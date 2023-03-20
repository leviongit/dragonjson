module LevisLibs
  module JSON
    class JSONKeyError < StandardError
    end

    class JSONUnsupportedType < StandardError
    end

    class << self
      def write(value, indent_size = 4)
        raise ArgumentError, "Top-level value must be either an Array or a Hash" unless Array === value || Hash === value

        value.to_json(
          indent_depth: 0,
          indent_size: indent_size,
          minify: indent_size == -1
        )
      end
    end

    class ::Hash
      def to_json(
        indent_depth: 0,
        indent_size: 4,
        minify: false,
        space_in_empty: true
      )
        raise JSONKeyError, "Not all keys are instances of `String` or `Symbol`" if !keys.all? { String === _1 || Symbol === _1 }

        return "{#{space_in_empty && !minify ? " " : ""}}" if self.length == 0

        space = minify ? "" : " "
        pairs = self.map { |k, v| "#{k.to_json}:#{space}#{v.to_json(indent_depth: indent_depth + 1, indent_size: indent_size, minify: minify, space_in_empty: space_in_empty)}" }

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
        space_in_empty: true
      )
        return "[#{space_in_empty && !minify ? " " : ""}]" if self.length == 0

        space = minify ? "" : " "
        values = self.map { |v| "#{v.to_json(indent_depth: indent_depth + 1, indent_size: indent_size, minify: minify, space_in_empty: space_in_empty)}" }

        if minify
          "[#{values.join(",")}]"
        else
          indent = " " * (indent_depth * indent_size)
          indent_p1 = " " * ((indent_depth + 1) * indent_size)
          <<~JSON
            [
            #{indent_p1}#{values.join(",\n#{indent_p1}")}
            #{indent}]
          JSON
        end
      end
    end

    class ::Numeric
      def to_json(
        indent_depth: 0,
        indent_size: 4,
        minify: false,
        space_in_empty: true
      )
        self.inspect
      end
    end

    class ::TrueClass
      def to_json(
        indent_depth: 0,
        indent_size: 4,
        minify: false,
        space_in_empty: true
      )
        "true"
      end
    end

    class ::FalseClass
      def to_json(
        indent_depth: 0,
        indent_size: 4,
        minify: false,
        space_in_empty: true
      )
        "false"
      end
    end

    class ::NilClass
      def to_json(
        indent_depth: 0,
        indent_size: 4,
        minify: false,
        space_in_empty: true
      )
        "null"
      end
    end

    class ::String
      def to_json(
        indent_depth: 0,
        indent_size: 4,
        minify: false,
        space_in_empty: true
      )
        self.inspect
      end
    end

    class ::Symbol
      def to_json(
        indent_depth: 0,
        indent_size: 4,
        minify: false,
        space_in_empty: true
      )
        self.to_s.inspect
      end
    end

    class ::Object
      def to_json(
        indent_depth: 0,
        indent_size: 4,
        minify: false,
        space_in_empty: true
      )
        raise JSONUnsupportedType, "Object of class #{self.class.name} cannot be serialized to JSON"
      end
    end
  end

  class ::GTK::Runtime
    def write_json(filename, hash_or_array, indent_size = 4)
      write_file(filename, hash_or_array.to_json(indent_size: indent_size, minify: indent_size == -1))
    end
  end
end
