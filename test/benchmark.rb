require "json"

json = $gtk.read_file("crimes.json")

def benchmark
  GC.start
  start = Time.now
  yield
  (Time.now - start) * 1000
end

puts_immediate "Parsing `test/crimes.json` 20 times…"

threshhold = 20.map do
  i = 0
  n = json.size

  benchmark do
    while i < n
      json.getbyte(i)
      i += 1
    end
  end
end
puts_immediate "Threshhold Time: #{threshhold.min.to_sf}ms"

data = 20.map { benchmark { Argonaut::JSON.parse(json) } }
mean = data.sum / data.size
var = data.map { |time| (time - mean) ** 2 }.sum / data.size
puts_immediate "Average Time: #{mean.to_sf}ms ± #{Math.sqrt(var).to_sf}ms"
puts_immediate "Fastest Time: #{data.min.to_sf}ms"
puts_immediate "Slowest Time: #{data.max.to_sf}ms"

$gtk.write_file("tmp/benchmark.json", <<~JSON)
  [
    {
      "name": "Time to parse crimes.json",
      "value": #{mean},
      "unit": "ms",
      "range": "± #{Math.sqrt(var).to_sf}ms"
    }
  ]
JSON
