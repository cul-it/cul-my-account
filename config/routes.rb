MyAccount::Engine.routes.draw do
  match '/login' => 'account#intro', via: [:get]
  match '/' => 'account#index', via: [:get, :post], as: 'myaccount'
  match '/ajax' => 'account#ajax', via: [:get]
  match '/get_patron_stuff' => 'account#get_patron_stuff', via: [:get]
end
