require_dependency "my_account/application_controller"

require 'net/http'
require 'uri'
require 'json'
require 'xmlsimple'

module MyAccount

  class AccountController < ApplicationController

    def index
      show
    end

    def show
      ###############
      netid = 'mjc12'
      ###############
      @patron = get_patron_info netid
      @checkouts, @available_requests, @pending_requests, @fines, @bd_requests = get_patron_stuff netid
      Rails.logger.debug "mjc12test: BD items #{@bd_requests}"
      @pending_requests += @bd_requests.select{ |r| r['status'] != 'ON LOAN'}
    end

    def get_patron_info netid
      uri = URI.parse("#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}")
      response = Net::HTTP.get_response(uri)
      record = JSON.parse(response.body)
      record[netid]
    end

    def get_patron_stuff netid
      uri = URI.parse("#{ENV['MY_ACCOUNT_ILSAPI_URL']}?netid=#{netid}")
      Rails.logger.debug "mjc12test: uri #{uri}"

      response = Net::HTTP.get_response(uri)
      Rails.logger.debug "mjc12test: body '#{response.body}'"
      record = JSON.parse(response.body)
      checkouts = []
      pending_requests = []
      available_requests = []
      record['items'].each do |i|
        # TODO: items returned with a status of 'finef' appear to be duplicates, only
        # indicating that a fine or fee is applied to that item. So we don't need them
        # in this list? But maybe check the fine-related functions below to see if we
        # need to do anything with this
        next if i['status'] == 'finef'
        # 'ttype' appears to be for a Voyager request - H, R, or ? for hold, recall, call slip
        if i['system'] == 'voyager' && (i['ttype'] != 'H' && i['ttype'] != 'R')
          checkouts << i
        else
          if i['status'] == 'waiting'
            available_requests << i
          else
            pending_requests << i
          end
        end
       # i['system'] != 'voyager' || i['ttype'].present? ? pending_requests << i : checkouts << i
      end
      fines = get_patron_fines netid
      #bd_items = get_bd_requests netid
      bd_items = []
      [checkouts, available_requests, pending_requests, fines, bd_items]
    end

    def get_patron_fines netid
      uri = URI.parse("#{ENV['VXWS_URL']}/patron/#{patron_id(netid)}/circulationActions/debt/fines?patron_homedb=#{ENV['VOYAGER_DB_ID']}")
      response = Net::HTTP.get_response(uri)
      xml = XmlSimple.xml_in response.body
      #fines = xml['fines'][0]['institution'][0]['fine']
      fines = []
      fine_detail = []
      fines.each do |f|
        url = f['href'].gsub('http://127.0.0.1:7014/', 'https://catalog.library.cornell.edu/')
        fine_detail << get_fine_detail(url)
      end
      fine_detail
    end

    def get_fine_detail fine_url
      uri = URI.parse(fine_url)
      response = Net::HTTP.get_response(uri)
      xml = XmlSimple.xml_in response.body
      xml['resource'][0]['fine'][0]    
    end

    def patron_id(netid)
      uri = URI.parse("#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}")
      response = Net::HTTP.get_response(uri)
      record = JSON.parse(response.body)
      record[netid]['patron_id']
    end

    def patron_barcode(netid)
      uri = URI.parse("#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}")
      response = Net::HTTP.get_response(uri)
      record = JSON.parse(response.body)
      record[netid]['barcode']
    end

    def get_bd_requests(netid)
      barcode = patron_barcode(netid)
      # Set parameters for the Borrow Direct API
      BorrowDirect::Defaults.library_symbol = 'CORNELL'
      BorrowDirect::Defaults.find_item_patron_barcode = barcode
      BorrowDirect::Defaults.timeout = ENV['BORROW_DIRECT_TIMEOUT'].to_i || 30 # (seconds)
      BorrowDirect::Defaults.api_base = BorrowDirect::Defaults::PRODUCTION_API_BASE
      BorrowDirect::Defaults.api_key = ENV['BORROW_DIRECT_PROD_API_KEY']

      items = BorrowDirect::RequestQuery.new(barcode).requests('open')
      Rails.logger.debug "mjc12test: BD items #{items}"
      # Returns an array of BorrowDirect::RequestQuery::Item
      cleaned_items = []
      items.each do |item|
        Rails.logger.debug "mjc12test: BD item raw #{item.inspect}"
        cleaned_items << { 'tl' => item.title, 'au' => '', 'system' => 'bd', 'status' => item.request_status }
      end

      cleaned_items

    end

  end

end
