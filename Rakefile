require 'rubygems'
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "pcapr-local"
  gem.homepage = "http://github.com/pcapr-local/pcapr-local"
  gem.license = "MIT"
  gem.summary = %Q{Manage your pcap collection}
  gem.description = %Q{Index, Browse, and Query your vast pcap collection.}
  gem.email = "nbaggott@gmail.com"
  gem.authors = ["Mu Dynamics"]
  gem.add_dependency "rest-client", ">= 1.6.1"
  gem.add_dependency "couchrest", "~> 1.0.1"
  gem.add_dependency "sinatra", "~> 1.1.0"
  gem.add_dependency "json", ">= 1.4.6"
  gem.add_dependency "thin", "~> 1.2.7"
  gem.add_dependency "rack", "~> 1.2.1"
  gem.add_dependency "rack-contrib", "~> 1.1.0"
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  #  gem.add_runtime_dependency 'jabber4r', '> 0.1'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
  gem.add_development_dependency "shoulda", ">= 0"
  gem.add_development_dependency "bundler", "~> 1.0.0"
  gem.add_development_dependency "jeweler", "~> 1.5.2"
  gem.add_development_dependency "rcov", ">= 0"

end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

require 'rcov/rcovtask'
Rcov::RcovTask.new(:rcov) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "pcapr-local #{version}"
  rdoc.rdoc_files.include('README*')
end
