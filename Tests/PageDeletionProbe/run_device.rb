require 'json'
require 'open3'
require 'securerandom'
require 'tempfile'

$stdout.sync = true
device = ARGV.fetch(0)
results = []

def run(device, *arguments)
  Tempfile.create(['radix-deletion-device', '.json']) do |file|
    output, = Open3.capture2e('xcrun', 'devicectl', 'device', 'process', 'launch',
      '--device', device, '--timeout', '60', '--json-output', file.path, '--console',
      'com.desmond.radix.deletionqa', *arguments)
    metadata = JSON.parse(File.read(file.path))
    termination = metadata.dig('result', 'terminationResult')
    # Only parse JSON emitted by our probe; device status comes from its JSON file.
    payload = output.lines.map do |line|
      next unless line.start_with?('{')
      JSON.parse(line)
    end.compact.last
    raise "Device launch failed: #{output}" unless payload && termination
    [payload, termination]
  end
end

%w[before journal sentences first-preference-store preferences first-image images].each do |phase|
  id = SecureRandom.uuid
  report, termination = run(device, 'interrupt', id, phase)
  raise "Expected signal 9: #{report}, #{termination}" unless termination['terminatingSignal'] == 9
  report, termination = run(device, 'recover', id)
  raise "Recovery failed: #{report}" unless termination['exitCode'] == 0 && report['result'] == 'passed'
  puts JSON.generate(report)
end

[100, 1000, 5000].each do |pages|
  3.times do
    report, termination = run(device, 'benchmark', SecureRandom.uuid, pages.to_s)
    raise "Benchmark failed: #{report}" unless termination['exitCode'] == 0 && report['result'] == 'passed'
    results << report
    puts JSON.generate(report)
  end
end

medians = results.group_by { |r| r['pages'] }.transform_values do |runs|
  runs.map { |r| r['deletion_ms'] }.sort[1]
end
commits = results.group_by { |r| r['pages'] }.transform_values do |runs|
  runs.map { |r| r['commit_ms'] }.sort[1]
end
puts JSON.generate('result' => 'passed', 'interruption_cases' => 7, 'benchmark_runs' => 9, 'median_deletion_ms' => medians, 'median_commit_ms' => commits)
