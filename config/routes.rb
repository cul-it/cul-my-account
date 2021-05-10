MyAccount::Engine.routes.draw do
  match '/login' => 'account#intro', via: [:get]
  match '/' => 'account#index', via: [:get, :post], as: 'myaccount'
  match '/ajax' => 'account#ajax', via: [:get]
  match '/get_patron_stuff' => 'account#get_patron_stuff', via: [:post]
  match '/get_folio_data' => 'account#get_folio_data', via: [:post]
  match '/ajax_checkouts' => 'account#ajax_checkouts', via: [:post]
  match '/ajax_fines' => 'account#ajax_fines', via: [:post]
end
