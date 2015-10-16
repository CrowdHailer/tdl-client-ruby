require 'rake/testtask'
require 'coveralls/rake/task'


#~~~~~~~ Test

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

task :default => :test

require 'cucumber/rake/task'

Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = 'features'
end

Coveralls::RakeTask.new
task :features_with_coveralls => [:features, 'coveralls:push']

#~~~~~~~~~ Play

desc 'Run the example'
task :example do
  sh 'ruby -I lib examples/add_numbers.rb'
end


desc 'Run the test playground'
task :playground do
  sh 'ruby -I lib ./features/utils/jmx/broker/playground.rb'
end


#~~~~~~~~ Deploy

require 'tdl/version'

task :build do
  system 'gem build tdl-client-ruby.gemspec'
end

task :release => :build do
  system "gem push tdl-client-ruby-#{TDL::VERSION}.gem"
end
