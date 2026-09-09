require 'json'
require 'open3'
require 'securerandom'
require 'tempfile'

$stdout.sync = true
device = ARGV.fetch(0)
sizes = [10_000, 50_000]
runs = []

def run(device, *arguments)
  Tempfile.create(['radix-sentence-examples-device', '.json']) do |file|
    output, = Open3.capture2e(
      'xcrun', 'devicectl', 'device', 'process', 'launch',
      '--device', device, '--timeout', '120', '--json-output', file.path,
      '--console', 'com.desmond.radix.sentenceexamplesqa', *arguments
    )
    metadata = JSON.parse(File.read(file.path))
    termination = metadata.dig('result', 'terminationResult')
    payload = output.lines.map do |line|
      JSON.parse(line) if line.start_with?('{')
    rescue JSON::ParserError
      nil
    end.compact.last
    raise "Device launch failed: #{output}" unless payload && termination
    raise "Probe failed: #{payload}" unless payload['result'] == (arguments.first == 'seed' ? 'seeded' : 'passed')
    payload
  end
end

sizes.each do |size|
  3.times do
    id = SecureRandom.uuid
    seed = run(device, 'seed', id, size.to_s)
    result = run(device, 'benchmark', id, size.to_s)
    runs << result.merge('seed_ms' => seed.fetch('seed_ms'))
    puts JSON.generate(runs.last)
  end
end

summary = sizes.to_h do |size|
  matching = runs.select { |run| run['sentences'] == size }
  median = ->(key) { matching.map { |run| run.fetch(key) }.sort[1] }
  [size, {
    'first_page_ms' => median.call('first_page_ms'),
    'second_page_ms' => median.call('second_page_ms'),
    'third_page_ms' => median.call('third_page_ms'),
    'maximum_frame_gap_ms' => matching.map { |run| run.fetch('maximum_frame_gap_ms') }.max,
    'seed_ms' => median.call('seed_ms')
  }]
end
puts JSON.generate('result' => 'passed', 'runs' => runs.count, 'median_by_sentence_count' => summary)
