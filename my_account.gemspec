$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require 'my_account/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "my_account"
  s.version     = MyAccount::VERSION
  s.authors     = ["Matt Connolly"]
  s.email       = ["mjc12@cornell.edu"]
  s.homepage    = "http://catalog.library.cornell.edu/myaccount"
  s.summary     = "User account page for Cornell University Library online catalog"
  s.description = "Provides a user account page for the Cornell University Library online catalog, including user account information, loans, requests, and fines." 
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency 'rails', '~> 6.1'
  s.add_dependency 'blacklight',['>= 7.0']
  s.add_dependency 'xml-simple'
  s.add_dependency 'rest-client'
  s.add_dependency 'cul-folio-edge', '~> 3.2'

  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "sqlite3", '~> 1.4'
end
