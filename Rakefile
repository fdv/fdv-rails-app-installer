require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/contrib/rubyforgepublisher'

PKG_VERSION        = '0.2.0'
PKG_NAME           = 'rails-app-installer'
PKG_FILE_NAME      = "#{PKG_NAME}-#{PKG_VERSION}"
RUBY_FORGE_PROJECT = 'rails-installer'
RUBY_FORGE_USER    = 'scottlaird'

spec = Gem::Specification.new do |s|
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.authors = ["Scott Laird"]
  s.email = "scott@sigkill.org"
  s.homepage = "http://scottstuff.net"
  s.platform = Gem::Platform::RUBY
  s.summary = "An installer for Rails apps"
  s.description = ""
  s.files = FileList['bin/*', 'lib/*', 'examples/*', 'README']
  s.has_rdoc = true
  s.extra_rdoc_files = FileList['README', 'lib/rails-installer/*']
  s.rdoc_options << '--main' << 'RailsInstaller'
  s.add_dependency("mongrel", ">= 0.3.13.3")
  s.add_dependency("mongrel_cluster", ">= 0.2.0")
  s.add_dependency("sqlite3-ruby", ">= 1.1.0")
  s.autorequire = 'rails-installer'
  s.executables = ['rails-app-installer-setup', 'rails-backup', 'rails-restore']
end

Rake::GemPackageTask.new(spec) do |p|
end

Rake::RDocTask.new do |rd|
  rd.main = "RailsInstaller"
end

desc "Publish the release files to RubyForge."
task :rubyforge_upload do
  `rubyforge login`
  release_command = "rubyforge add_release #{PKG_NAME} #{PKG_NAME} '#{PKG_NAME}-#{PKG_VERSION}' pkg/#{PKG_NAME}-#{PKG_VERSION}.gem"
  puts release_command
  system(release_command)
end
