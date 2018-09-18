require_dependency "my_account/application_controller"

require 'net/http'
require 'uri'
require 'json'
#require 'xmlsimple'

module MyAccount

  class AccountController < ApplicationController

    def show
      netid = 'mjc12'
      @patron = get_patron_info netid
    end

    def get_patron_info netid
      uri = URI.parse("https://lstools.library.cornell.edu/patrons/patron_info_service.cgi/netid/#{netid}")
      response = Net::HTTP.get_response(uri)
      record = JSON.parse(response.body)
      record[netid]
    end

  end

end
