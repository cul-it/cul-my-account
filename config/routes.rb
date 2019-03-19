MyAccount::Engine.routes.draw do
  match '/' => 'account#index', via: [:get, :post]
end
