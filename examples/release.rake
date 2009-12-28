require 'rake/gempackagetask'

PKG_VERSION = "1.0.0"
PKG_NAME = "$APPNAME"
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

spec = Gem::Specification.new do |s|
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.summary = "FIXME"
  s.description = "FIXME"
  s.has_rdoc = false
  
  s.files = Dir.glob('**/*', File::FNM_DOTMATCH).reject do |f| 
     [ /\.$/, /config\/database.yml$/, /config\/database.yml-/, 
     /database\.sqlite/,
     /\.log$/, /^pkg/, /\.svn/, /^vendor\/rails/, /\~$/, 
     /\/\._/, /\/#/ ].any? {|regex| f =~ regex }
  end
  s.require_path = '.'
  s.author = "FIXME"
  s.email = "FIXME@example.com"
  s.homepage = "http://www.FIXME.com"  
  s.rubyforge_project = "FIXME"
  s.platform = Gem::Platform::RUBY 
  s.executables = ['$APPNAME']
  
  s.add_dependency("rails", "= 1.1.6")
  s.add_dependency("mongrel", ">= 0.3.13.3")
  s.add_dependency("mongrel_cluster", ">= 0.2.0")
  s.add_dependency("sqlite3-ruby", ">= 1.1.0")
  s.add_dependency("rails-app-installer", ">= 0.1.0")
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = false
  p.need_zip = false
end
