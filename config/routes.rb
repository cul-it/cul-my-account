MyAccount::Engine.routes.draw do
  match '/login' => 'account#intro', via: [:get]
  match '/' => 'account#index', via: [:get, :post], as: 'myaccount'
  match '/get_folio_data' => 'account#get_folio_data', via: [:post]
  match '/get_illiad_data' => 'account#get_illiad_data', via: [:post]
  match '/ajax_checkouts' => 'account#ajax_checkouts', via: [:post]
  match '/ajax_illiad_available' => 'account#ajax_illiad_available', via: [:post]
  match '/ajax_illiad_pending' => 'account#ajax_illiad_pending', via: [:post]
  match '/ajax_fines' => 'account#ajax_fines', via: [:post]
  match '/ajax_renew' => 'account#ajax_renew', via: [:post]
end
