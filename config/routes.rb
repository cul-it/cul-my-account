MyAccount::Engine.routes.draw do
  get '/' => 'account#show'
  get '/index' => 'account#show'
end
