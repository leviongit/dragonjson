def test_json_write_indent_size(_args, assert)
  object = {
    subhash: { array: [20, 'string', true], hash: { x: 30 } },
    array: [22, 'string', { x: 33, nothing: nil }]
  }

  json = LevisLibs::JSON.write(object, indent_size: 2)

  expected = <<~JSON.strip
    {
      "subhash": {
        "array": [
          20,
          "string",
          true
        ],
        "hash": {
          "x": 30
        }
      },
      "array": [
        22,
        "string",
        {
          "x": 33,
          "nothing": null
        }
      ]
    }
  JSON
  assert.equal! json, expected
end

def test_json_write_minify(_args, assert)
  object = {
    subhash: { array: [20, 'string', true], hash: { x: 30 } },
    array: [22, 'string', { x: 33, nothing: nil }]
  }

  json = LevisLibs::JSON.write(object, minify: true)

  assert.equal! json, '{"subhash":{"array":[20,"string",true],"hash":{"x":30}},"array":[22,"string",{"x":33,"nothing":null}]}'
end

def test_json_parse_default(_args, assert)
  object = { some_key: 'some_value' }
  json = LevisLibs::JSON.write(object)

  assert.equal! LevisLibs::JSON.parse(json), {'some_key' => 'some_value'}
end

def test_json_parse_symbolize_keys(_args, assert)
  object = { some_key: 'some_value' }
  json = LevisLibs::JSON.write(object)

  assert.equal! LevisLibs::JSON.parse(json, symbolize_keys: true), object
end

def test_json_extensions_symbols(_args, assert)
  object = { some_key: :some_value }
  json = LevisLibs::JSON.write(object, extensions: true)

  assert.equal! LevisLibs::JSON.parse(json, symbolize_keys: true, extensions: true), object
end

def test_json_extensions_objects(_args, assert)
  object = { main_character: TestCharacter.new(name: 'Levi', hp: 97) }
  json = LevisLibs::JSON.write(object, extensions: true)

  assert.equal! LevisLibs::JSON.parse(json, symbolize_keys: true, extensions: true), object
end

class TestCharacter
  attr_reader :name, :hp

  def initialize(name:, hp:)
    @name = name
    @hp = hp
  end

  def to_json(**kw)
    super(
      value: { name: @name, hp: @hp },
      **kw
    )
  end

  def ==(other)
    @name == other.name && @hp == other.hp
  end

  def inspect
    "TestCharacter(name: #{@name}, hp: #{@hp})"
  end

  def self.from_json(json)
    TestCharacter.new(name: json[:name], hp: json[:hp])
  end
end
