require "rake/testtask"

namespace :test do
  Rake::TestTask.new do |t|
    t.libs << 'lib'
    t.libs << 'test'
    t.test_files = FileList['test/**/*_test.rb']
 end
 task :default => :test
end

desc 'Run ruby tests'
task :test => 'test:default'
