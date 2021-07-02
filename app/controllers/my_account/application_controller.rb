module MyAccount
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout 'layouts/blacklight'

    # The following approach & methods for handling flash messages for AJAX calls are taken from
    # https://gist.github.com/hbrandl/5253211
    after_action :flash_to_headers

    private

    def flash_to_headers
      return unless request.xhr?
      msg = flash_message
      #replace german umlaute encoded in utf-8 to html escaped ones
      response.headers['X-Message'] = msg
      response.headers["X-Message-Type"] = flash_type.to_s

      flash.discard # don't want the flash to appear when you reload page
    end

    def flash_message
      [:error, :warning, :notice].each do |type|
        return flash[type] unless flash[type].blank?
      end
      # if we don't return something here, the above code will return "error, warning, notice"
      return ''
    end

    def flash_type
      #:keep will instruct the js to not update or remove the shown message.
      #just write flash[:keep] = true (or any other value) in your controller code
      [:error, :warning, :notice, :keep].each do |type|
        return type unless flash[type].blank?
      end
      #don't return the array from above which would happen if we don't have an explicit return statement
      #returning :empty will also allow you to easily know that no flash message was transmitted
      return :empty
    end
  end
end
