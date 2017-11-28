begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'bundler/gem_tasks'

namespace :bump do
  task :patch do
    system "bump patch --tag"
  end

  task :minor do
    system "bump minor --tag"
  end

  task :major do
    system "bump major --tag"
  end
end
