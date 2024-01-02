# dragonjson

## parsing json

```rb
LevisLibs::JSON.parse(json_string,
                      symbolize_keys: boolean,
                      extensions: boolean)
```

### arguments

1. `json_string` - `String` to be deserialized
2. `symbolize_keys` - `true`/`false` : turn the keys of hashes into `Symbol`s?
3. `extensions` - `true`/`false` : turn the extensions (lossless `Symbol`
   deserialization, user object serialization) on?

## serializing basic types to json

```rb
obj.to_json(indent_size: uint,
            minify: boolean,
            extensions: boolean)
```

### arguments

1. `indent_size` - `uint` : width of indentation
2. `minify` - `true`/`false` : whether to minify the json, overrides `indent_size`
3. `extensions` - `true`/`false` : turn the extensions (lossless `Symbol`
   deserialization, user object serialization) on?

### basic types

- `Hash`
- `Array`
- `Integer`
- `Float`
- `true`
- `false`
- `String`
- `Symbol` (lossy conversion if `extensions` is `false`)
