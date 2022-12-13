module MyAccount
  class Engine < ::Rails::Engine
    isolate_namespace MyAccount

    config.autoload_paths += Dir["#{config.root}/spec/support"]
    config.eager_load_paths += Dir["#{config.root}/lib"]
    config.assets.paths << config.root.join('/engines/my_account/app/assets/javascripts')
    config.assets.precompile << "my_account/application.js"
    config.assets.precompile << "my_account/account.js.coffee"
  end

  def self.config(&block)
    yield Engine.config if block
    Engine.config
  end
  
end
