require_dependency "my_account/application_controller"

require 'rest-client'
require 'json'
require 'xmlsimple'

module MyAccount

  class AccountController < ApplicationController
    before_filter :heading

    def heading
      @heading='My Account'
    end

    def index
      ###############
      netid = 'mjc12'
      ###############
      @patron = get_patron_info netid

      # Take care of any requested actions first based on query params
      if params['button'] == 'renew'
        Rails.logger.debug "mjc12test: Going into renew"
        items_to_renew = params.select { |param| param.match(/select\-.+/) }
        renew(items_to_renew) if items_to_renew.present?
      elsif params['button'] == 'cancel'
        Rails.logger.debug "mjc12test: Going into cancel"
        items_to_cancel = params.select { |param| param.match(/select\-.+/) }
        cancel items_to_cancel if items_to_cancel.present?
      end

      # Retrieve and display account info 
      @checkouts, @available_requests, @pending_requests, @fines, @bd_requests = get_patron_stuff netid
      @pending_requests += @bd_requests.select{ |r| r['status'] != 'ON LOAN' && r['status'] != 'ON_LOAN' }

      # HACK: this has to follow the assignment of @checkouts so that we have the item data available for export
      if params['button'] == 'export-checkouts'
        items_to_export = params.select { |param| param.match(/select\-.+/) }
        export items_to_export if items_to_export.present?
      end
    end

    # Given an array of item "ids" (of the form 'select-<id>'), return an array of the bare IDs
    def ids_from_strings items
      items.map { |item, value| item.match(/select\-(.+)/)[1] }
    end

    # Given a list of item "ids" (of the form 'select-<id>'), renew them (if possible) using the Voyager API
    def renew items

      if @patron['status'] != 'Active'
        flash[:error] = 'There is a problem with your account. The selected items could not be renewed.'
      else
        # Retrieve the list of item IDs that have been selected for renewal
        item_ids= ids_from_strings items
        if params['num_checkouts'] && items.length == params['num_checkouts'].length
          renew_all
        else
          item_ids = items.map do |item, value|
            item.match(/select\-(\d+)/)[1]
          end 
          Rails.logger.debug "mjc12test: item_ids #{item_ids}"
        end

        # Invoke Voyager APIs to do the actual renewals
        errors = false
        item_ids.each do |id|
          http = Net::HTTP.new("#{ENV['MY_ACCOUNT_VOYAGER_URL']}")
          url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/loans/#{ENV['VOYAGER_DB_ID']}%7C#{id}?patron_homedb=#{ENV['VOYAGER_DB_ID']}"
          response = RestClient.post(url, {})
          xml = XmlSimple.xml_in response.body
          if xml && xml['reply-code'][0] != 0
            flash[:error] = "The item could not be renewed. " + xml['reply-text'][0]
            errors = true
          end
        end

        if item_ids.count == 1 && errors == false
          flash[:notice] = 'This item has been renewed'
        elsif item_ids.count > 2 && errors == false
          flash[:notice] = "#{item_ids.count} items have been renewed"
        end

      end
    end

    def renew_all
      Rails.logger.debug "mjc12test: Renewing all! #{}"
      # TODO: implement this

      flash[:notice] = 'All eligible items have been renewed'
    end

    # Given a list of item "ids" (of the form 'select-<id>'), cancel them (if possible)
    # Requested items could be Voyager items, ILLiad, or Borrow Direct -- so use whichever API is appropriate
    def cancel items
      request_ids = ids_from_strings items
      Rails.logger.debug "mjc12test: items #{request_ids}"
      request_ids.each do |id|
        if id.match(/^COR/)
          # TODO: implement this
          # do a Borrow Direct cancel
        elsif id.match(/^illiad/)
          # TODO: implement this
          # do an ILLiad cancel
        else
          # do a Voyager cancel
          http = Net::HTTP.new("#{ENV['MY_ACCOUNT_VOYAGER_URL']}")
          # Remember that Voyager uses the '/holds/' path for both holds and recalls in order to confuse us
          url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/requests/holds/#{ENV['VOYAGER_DB_ID']}%7C#{id}?patron_homedb=#{ENV['VOYAGER_DB_ID']}"
          response = RestClient.delete(url, {})
        end
      end

      if request_ids.count == 1
        flash[:notice] = 'Your request has been cancelled'
      elsif request_ids.count > 1
        flash[:notice] = 'Your requests have been cancelled'
      end

    end

    def export items
      item_ids = ids_from_strings items
      ris_output = ''
      item_ids.each do |id|
        item = @checkouts.detect { |i| i['iid'] == id }
        Rails.logger.debug "mjc12test: item #{item}"
      #  ris_output += "TY  - BOOK\n"
        ris_output += "CY  - #{item['ou_pp']}\n"
        ris_output += "PY  - #{item['ou_yr']}\n"
        ris_output += "PB  - #{item['ou_pb']}\n"
        ris_output += "T1  - #{item['ou_title']}\n"
        ris_output += "AU  - #{item['au']}\n"
        ris_output += "SN  - #{item['ou_isbn']}\n"
        # LA  - English
        ris_output += "UR  - http://newcatalog.library.cornell.edu/catalog/#{item['bid']}\n"
        ris_output += "C1  - #{item['callno']}\n"
        ris_output += "ER  -\n"
      end

      Rails.logger.debug "mjc12test: CITATIONS: #{ris_output}"
    end

    def get_patron_info netid
      response = RestClient.get "#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}"
      record = JSON.parse response.body
      record[netid]
    end

    def get_patron_stuff netid
      response = RestClient.get "#{ENV['MY_ACCOUNT_ILSAPI_URL']}?netid=#{netid}"
      record = JSON.parse response.body
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
          # This is a Voyager hold or recall. Rather than tracking the item ID, we need the request
          # id for potential cancellations.
          # HACK: substitute request id for item id
          # TODO: come up with a better way of doing this
          i['iid'] = i['tid'] # not sure why 'tid' is used in the ILSAPI return - "transaction ID"?
          # add a special "item id" for ILLiad items
          if i['system'] == 'illiad'
            i['iid'] = "illiad-#{i['TransactionNumber']}" 
            i['requestDate'] = DateTime.parse(i['TransactionDate']).strftime("%-m/%-d/%y")
          end
            
          if i['status'] == 'waiting'
            available_requests << i
          else
            pending_requests << i
          end
        end
       # i['system'] != 'voyager' || i['ttype'].present? ? pending_requests << i : checkouts << i
      end
      fines = get_patron_fines netid
      bd_items = get_bd_requests netid
      [checkouts, available_requests, pending_requests, fines, bd_items]
    end

    def get_patron_fines netid
      response = RestClient.get "#{ENV['VXWS_URL']}/patron/#{patron_id(netid)}/circulationActions/debt/fines?patron_homedb=#{ENV['VOYAGER_DB_ID']}"
      xml = XmlSimple.xml_in response.body
      fines = xml['fines'] ? xml['fines'][0]['institution'][0]['fine'] : []
      fine_detail = []
      fines.each do |f|
        url = f['href'].gsub('http://127.0.0.1:7014/', 'https://catalog.library.cornell.edu/')
        fine_detail << get_fine_detail(url)
      end
      fine_detail
    end

    def get_fine_detail fine_url
      response = RestClient.get fine_url
      xml = XmlSimple.xml_in response.body
      xml['resource'][0]['fine'][0]    
    end

    def patron_id(netid)
      response = RestClient.get "#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}"
      record = JSON.parse(response.body)
      record[netid]['patron_id']
    end

    def patron_barcode(netid)
      response = RestClient.get "#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}"
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

     begin
        items = BorrowDirect::RequestQuery.new(barcode).requests('open')
      rescue BorrowDirect::Error => e
        # The Borrow Direct gem doesn't differentiate among all of the BD API error types.
        # In this case, PUBQR004 is an exception raised when there are no results for the query
        # (why should that cause an exception??). We don't want to crash and burn just because
        # the user doesn't have any BD requests in the system. But if it's anything else,
        # raise it again -- that indicates a real problem.
        raise unless e.message.include? 'PUBQR004'  
        items = []
      end
      # Returns an array of BorrowDirect::RequestQuery::Item
      cleaned_items = []
      items.each do |item|
        # For the final item, we add a fake item ID number (iid) for compatibility with other items in the system
        cleaned_items << { 'tl' => item.title, 'au' => '', 'system' => 'bd', 'status' => item.request_status, 'iid' => item.request_number }
      end
      cleaned_items

    end

  end

end
