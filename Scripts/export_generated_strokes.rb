#!/usr/bin/env ruby
# Exports Radix-generated stroke JSON from the local app cache into static files
# that GitHub Pages can serve through animate.html.

require "fileutils"
require "sqlite3"

project_root = File.expand_path("..", __dir__)
cache_path = ARGV[0] || File.expand_path("~/Documents/user_character_strokes.db")
output_dir = File.join(project_root, "strokes")

unless File.exist?(cache_path)
  abort "Generated stroke cache not found: #{cache_path}"
end

FileUtils.mkdir_p(output_dir)

db = SQLite3::Database.new(cache_path)
rows = db.execute("SELECT character, data FROM strokes ORDER BY character")

rows.each do |character, data|
  codepoint = character.each_codepoint.first
  next unless codepoint && data

  filename = File.join(output_dir, "u#{codepoint.to_s(16)}.json")
  File.write(filename, data)
end

puts "Exported #{rows.length} generated stroke file(s) to #{output_dir}"
