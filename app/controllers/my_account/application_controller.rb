module MyAccount
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout 'layouts/blacklight'
  end
end
