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
      @checkouts = get_patron_checkouts netid
    end

    def get_patron_info netid
      uri = URI.parse("#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}")
      response = Net::HTTP.get_response(uri)
      record = JSON.parse(response.body)
      record[netid]
    end

    def get_patron_checkouts netid
      uri = URI.parse("#{ENV['MY_ACCOUNT_ILSAPI_URL']}?netid=#{netid}")
      response = Net::HTTP.get_response(uri)
      record = JSON.parse(response.body)
      record['items']
    end

  end

end
