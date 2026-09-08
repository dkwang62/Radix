require 'json'
require 'open3'
require 'securerandom'
require 'timeout'

binary = ARGV.fetch(0)
results = []

def run(binary, *arguments)
  output = nil
  status = nil
  Open3.popen2e(binary, *arguments) do |input, stream, process|
    input.close
    begin
      Timeout.timeout(60) do
        output = stream.read
        status = process.value
      end
    rescue Timeout::Error
      Process.kill('KILL', process.pid)
      process.value
      raise
    end
  end
  [JSON.parse(output), status]
end

%w[before journal sentences first-preference-store preferences first-image images].each do |phase|
  id = SecureRandom.uuid
  report, status = run(binary, 'interrupt', id, phase)
  raise "Expected SIGKILL at #{phase}: #{report}" unless status.signaled? && status.termsig == 9
  report, status = run(binary, 'recover', id)
  raise "Recovery failed: #{report}" unless status.success? && report['result'] == 'passed'
  results << report
  puts JSON.generate(report)
end

[100, 1000, 5000].each do |pages|
  3.times do
    report, status = run(binary, 'benchmark', SecureRandom.uuid, pages.to_s)
    raise "Benchmark failed: #{report}" unless status.success? && report['result'] == 'passed'
    results << report
    puts JSON.generate(report)
  end
end

medians = results.select { |r| r.key?('pages') }.group_by { |r| r['pages'] }.transform_values do |runs|
  runs.map { |r| r['deletion_ms'] }.sort[1]
end
commits = results.select { |r| r.key?('pages') }.group_by { |r| r['pages'] }.transform_values do |runs|
  runs.map { |r| r['commit_ms'] }.sort[1]
end
puts JSON.generate('result' => 'passed', 'interruption_cases' => 7, 'benchmark_runs' => 9, 'median_deletion_ms' => medians, 'median_commit_ms' => commits)
