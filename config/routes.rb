MyAccount::Engine.routes.draw do
  match '/login' => 'account#intro', via: [:get]
  match '/' => 'account#index', via: [:get, :post], as: 'myaccount'
end
