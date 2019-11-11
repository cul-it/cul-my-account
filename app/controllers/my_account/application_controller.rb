module MyAccount
  class ApplicationController < ActionController::Base
    protect_from_forgery prepend: true, with: :exception
    layout 'layouts/blacklight'
  end
end
