require 'fileutils'
require 'open3'
require 'tmpdir'

binary = ARGV.fetch(0)

def run(binary, root, *arguments)
  mode, *rest = arguments
  _output, status = Open3.capture2e(binary, mode, root, *rest)
  status
end

Dir.mktmpdir('radix-restore-rollback') do |root|
  [-1, 0, 1, 2, 3].each do |stage|
    FileUtils.rm_rf(root)
    status = run(binary, root, 'interrupt', stage.to_s)
    raise "expected SIGKILL at incoming stage #{stage}" unless status.signaled? && status.termsig == 9
    raise "recovery failed at incoming stage #{stage}" unless run(binary, root, 'recover').success?
    raise "verification failed at incoming stage #{stage}" unless run(binary, root, 'verify').success?
  end

  [0, 1, 2, 3].each do |stage|
    FileUtils.rm_rf(root)
    raise "rollback setup failed" unless run(binary, root, 'prepare-rollback').success?
    status = run(binary, root, 'recover', stage.to_s)
    raise "expected SIGKILL at rollback stage #{stage}" unless status.signaled? && status.termsig == 9
    raise "retry failed at rollback stage #{stage}" unless run(binary, root, 'recover').success?
    raise "verification failed at rollback stage #{stage}" unless run(binary, root, 'verify').success?
  end
end

puts "passed: 5 interrupted restores, 4 interrupted rollbacks"
