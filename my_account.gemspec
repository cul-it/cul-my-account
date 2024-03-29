$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "my_account/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "my_account"
  s.version     = MyAccount::VERSION
  s.authors     = ["Matt Connolly"]
  s.email       = ["mjc12@cornell.edu"]
  s.homepage    = "http://newcatalog.library.cornell.edu/myaccount"
  s.summary     = "Summary of MyAccount."
  s.description = "Description of MyAccount."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 6.1"
  s.add_dependency 'blacklight',['>= 7.0']
  s.add_dependency "xml-simple"
  s.add_dependency 'rest-client'
  s.add_dependency 'borrow_direct'
  s.add_dependency 'cul-folio-edge', ['>= 1.2.1']

  s.add_development_dependency "sqlite3"
end
