require "json.rb"

$gtk.list_files("data").each do |name|
  next unless name.delete_suffix!(".json")

  # SKIPPED: Inconclusive tests aren't necessarily a good signal.
  next if name.start_with?("i_")

  # SKIPPED: Causes a stack overflow.
  next if name == "n_structure_100000_opening_arrays"

  # SKIPPED: Causes a stack overflow.
  next if name == "n_structure_open_array_object"

  define_method("test_#{name}") do |args, assert|
    json = $gtk.read_file("data/#{name}.json")
    data = $gtk.stat_file("data/#{name}.rb") && $gtk.read_file("data/#{name}.rb")
    mesg = $gtk.stat_file("data/#{name}.err") && $gtk.read_file("data/#{name}.err")

    if data
      data = eval(data)
      assert.equal!(LevisLibs::JSON.parse(json), data, "Expected data can be found in test/data/#{name}.rb")
    elsif mesg
      begin
        LevisLibs::JSON.parse(json)
      rescue => e
        mesg = eval(mesg)
        assert.equal!(e.message, mesg, "Expected data can be found in test/data/#{name}.err")
      else
        raise "Unexpectedly parsed invalid JSON"
      end
    end
  end
end
