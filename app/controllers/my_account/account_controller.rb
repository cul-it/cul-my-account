require_dependency "my_account/application_controller"

require 'rest-client'
require 'json'
require 'xmlsimple'

module MyAccount

  class AccountController < ApplicationController
    before_action :heading
    before_action :authenticate_user, except: [:intro]

    def heading
      @heading='My Account'
    end

    def authenticate_user
      Rails.logger.debug "mjc12test: authenticating"
      if user.present?
        index
      else
        session[:cuwebauth_return_path] = myaccount_path
        if ENV['DEBUG_USER'] && Rails.env.development?
          index
        else
          redirect_to "#{request.protocol}#{request.host_with_port}/users/auth/saml"
        end
      end
    end

    def intro
      # This is the "landing page" that displays general info before the user clicks the button
      # to log in.
    end

    def index
      @patron = get_patron_info user
      if @patron.present?
        # Take care of any requested actions first based on query params
        if params['button'] == 'renew'
          Rails.logger.debug "mjc12test: Going into renew"
          items_to_renew = params.select { |param| param.match(/select\-.+/) }
          params['button'] = nil
          renew(items_to_renew) if items_to_renew.present?
        elsif params['button'] == 'cancel'
          Rails.logger.debug "mjc12test: Going into cancel"
          items_to_cancel = params.select { |param| param.match(/select\-.+/) }
          cancel items_to_cancel if items_to_cancel.present?
        end

        # Retrieve and display account info 
        @checkouts, @available_requests, @pending_requests, @fines, @bd_requests = get_patron_stuff user
        @pending_requests += @bd_requests.select{ |r| r['status'] != 'ON LOAN' && r['status'] != 'ON_LOAN' } if @bd_requests.present?
        @checkouts.sort! { |a,b| a['od'] && b['od'] ? a['od'] <=> b['od'] : a['od'] ? -1 : 1 }   # sort by due date
        # HACK: the API call that is used to build the hash of renewable (yes/no) status for checked-out
        # items times out with a nasty server error if the user has too many charged items. For now, arbitrarily
        # do this only for small collections of items. (This means that users with large collections won't see the
        # warning labels that certain items can't be renewed ... but the renewal process itself should still work.)
        Rails.logger.debug("tlw72 > @bd_requests = " + @bd_requests.inspect)
        Rails.logger.debug("tlw72 > @checkouts = " + @checkouts.inspect)
        Rails.logger.debug("tlw72 > @pending_requests = " + @pending_requests.inspect)
        if @checkouts.length <= 100
          @renewable_lookup_hash = get_renewable_lookup user
        end

        # HACK: this has to follow the assignment of @checkouts so that we have the item data available for export
        if params['button'] == 'export-checkouts'
          items_to_export = params.select { |param| param.match(/select\-.+/) }
          export items_to_export if items_to_export.present?
        end
      end
    end

    # Given an array of item "ids" (of the form 'select-<id>'), return an array of the bare IDs
    def ids_from_strings items
      Rails.logger.debug "mjc12test: items: #{items}"
      items.keys.map { |item, value| item.match(/select\-(.+)/)[1] }
    end

    # Use one of the Voyager API to retrieve a list of checked-out items that includes a canRenew
    # property. Use this to return a lookup hash based on item ID for later use. Unfortunately, if a patron
    # has hundreds of items checked out, this can time out on the Voyager side.  
    def get_renewable_lookup patron
      return nil if @patron.nil?
      http = Net::HTTP.new("#{ENV['MY_ACCOUNT_VOYAGER_URL']}")
      Rails.logger.debug "mjc12test: patron #{@patron}"
      url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/loans?patron_homedb=1@#{ENV['VOYAGER_DB']}"
      #response = RestClient.get(url)
      response = RestClient::Request.execute(method: :get, url: url, timeout: 120)
      xml = XmlSimple.xml_in response.body
      loans = xml['loans'] && xml['loans'][0]['institution'][0]['loan']
      #Rails.logger.debug "mjc12test: loans found #{loans} for xml #{xml}"
      ##############
      # loans.each do |loan|
      #   if (rand > 0.8)
      #     loan['canRenew'] = 'N'
      #   end
      # end
      ###############
      loans.map { |loan| [loan['href'][/\|(\d+)\?/,1], loan['canRenew']] }.to_h unless loans.nil?
    end

    # Given a list of item "ids" (of the form 'select-<id>'), renew them (if possible) using the Voyager API
    def renew items
      Rails.logger.debug "mjc12test: Going into renew with patron info: #{@patron}"
      if @patron['status'] != 'Active'
        flash[:error] = 'There is a problem with your account. The selected items could not be renewed.'
      else
        error_messages = []
        # Retrieve the list of item IDs that have been selected for renewal
        item_ids= ids_from_strings items

        # if @checkouts.length <= 100 
        #   @renewable_lookup_hash ||= get_renewable_lookup user
        # end
        if @renewable_lookup_hash.present?
          renewable_item_ids = item_ids.select { |iid| @renewable_lookup_hash[iid] == 'Y' }
          unrenewable_item_ids = item_ids.select { |iid| @renewable_lookup_hash[iid] == 'N' }
        else
          renewable_item_ids = item_ids
          unrenewable_item_ids = []
        end
        if params['num_checkouts'] && renewable_item_ids.length == params['num_checkouts'].to_i
          renew_all
        else
          Rails.logger.debug "mjc12test: renewable item_ids #{renewable_item_ids}"
          Rails.logger.debug "mjc12test: unrenewable item_ids #{unrenewable_item_ids}"

          # Invoke Voyager APIs to do the actual renewals
          errors = false
          successful_renewal_count = 0
          renewable_item_ids.each do |id|
            # Check for ILLiad item
            if id.start_with? 'illiad'
              transaction_id = id.split(/-/)[1]
              response = RestClient.get "https://ill-access.library.cornell.edu/illrenew.cgi?netid=#{@patron['netid']}&iid=#{transaction_id}"
              response = JSON.parse response.body
              Rails.logger.debug "mjc12test: got renew response: #{response['error']}"
              if response['error'].present?
                error_messages << "Could not renew item in ILLiad"
                Rails.logger.error "My Account: Couldn't renew ILLiad item with transaction ID #{transaction_id}. Request returned error: #{response['error']}"
                errors = true
              else
                successful_renewal_count += 1
              end
            else
              http = Net::HTTP.new("#{ENV['MY_ACCOUNT_VOYAGER_URL']}")
              url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/loans/1@#{ENV['VOYAGER_DB']}%7C#{id}?patron_homedb=1@#{ENV['VOYAGER_DB']}"
              Rails.logger.debug "mjc12test: Trying to renew with url: #{url}"
              response = RestClient.post(url, {})
              xml = XmlSimple.xml_in response.body
              Rails.logger.debug "mjc12test: response #{xml}"
              response_loan_info = xml && xml['renewal'][0]['institution'][0]['loan'][0]
              if xml && xml['reply-code'][0] != '0' 
                error_messages << "Item '#{response_loan_info['title'][0]}' could not be renewed due to an error:  " + xml['reply-text'][0]
                Rails.logger.error "My Account: couldn't renew item #{id}. XML returned: #{xml}"
                errors = true
              elsif response_loan_info && response_loan_info['renewalStatus'][0] != 'Success' 
                error_messages << "Item '#{response_loan_info['title'][0]}' could not be renewed due to an error: " + response_loan_info['renewalStatus'][0]
                Rails.logger.error "My Account: couldn't renew item #{id}. XML returned: #{xml}"
                errors = true
              else
                successful_renewal_count += 1
              end
            end
          end

          if renewable_item_ids.count == 1 && successful_renewal_count == 1 && errors == false
            flash[:notice] = 'This item has been renewed.'
          elsif successful_renewal_count > 1
            flash[:notice] = "#{successful_renewal_count} items were renewed."
          end
          if unrenewable_item_ids.count > 0
            error_messages << 'Some items were skipped because they could not be renewed. Ask a librarian for more information.'
          end
          error_messages = error_messages.join('<br/>').html_safe
          flash[:error] = error_messages if error_messages.present?
        end
        params.select! { |param| !param.match(/select\-.+/) }
      end
    end

    def renew_all
      Rails.logger.debug "mjc12test: Renewing all!"
      http = Net::HTTP.new("#{ENV['MY_ACCOUNT_VOYAGER_URL']}")
      url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/loans?institution=1@LOCAL&patron_homedb=1@#{ENV['VOYAGER_DB']}"
      response = RestClient.post(url, {})
      xml = XmlSimple.xml_in response.body
        Rails.logger.debug "mjc12test: response from renew all: #{xml}"
      if xml && xml['reply-code'][0] != '0'
        flash[:error] = "There was an error when trying to renew all items: " + xml['reply-text'][0]
        Rails.logger.error "My Account: couldn't renew all items. XML returned: #{xml}"
      else
        flash[:notice] = 'All items were renewed.'
      end
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
          url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/requests/holds/1@#{ENV['VOYAGER_DB']}%7C#{id}?patron_homedb=1@#{ENV['VOYAGER_DB']}"
          response = RestClient.delete(url, {})
        end
      end

      if request_ids.count == 1
        flash[:notice] = 'Your request has been cancelled.'
      elsif request_ids.count > 1
        flash[:notice] = 'Your requests have been cancelled.'
      end

    end

    def export items
      item_ids = ids_from_strings items
      ris_output = ''
      item_ids.each do |id|
        item = @checkouts.detect { |i| i['iid'] == id }
        # TODO: the TY field may need to be made dynamic to account for different material types -
        # see https://en.wikipedia.org/wiki/RIS_(file_format). But currently the item record passed in
        # does not indicate type.
        ris_output += "TY  - BOOK\n"
        ris_output += "CY  - #{item['ou_pp']}\n"
        ris_output += "PY  - #{item['ou_yr']}\n"
        ris_output += "PB  - #{item['ou_pb']}\n"
        ris_output += "T1  - #{item['ou_title']}\n"
        ris_output += "AU  - #{item['au']}\n"
        ris_output += "SN  - #{item['ou_isbn']}\n"
        # LA  - English
        ris_output += "UR  - http://newcatalog.library.cornell.edu/catalog/#{item['bid']}\n"
        ris_output += "CN  - #{item['callno']}\n"
        ris_output += "ER  -\n"
      end

      send_data ris_output, filename: 'citation.ris', type: 'text/ris'
    end

    def get_patron_info netid
      response = RestClient.get "#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}"
      record = JSON.parse response.body
      record[netid]
    end

    # This is the main lookup function. It retrieves a list of a user's requests and charged
    # items using the ilsapi CGI script.
    def get_patron_stuff netid
      record = nil
      begin 
        response = RestClient.get "#{ENV['MY_ACCOUNT_ILSAPI_URL']}?netid=#{netid}"
        record = JSON.parse response.body
      rescue => error
        Rails.logger.error "MyAccount error: Could not find a patron entry for #{netid}"
        msg = "We're sorry, but we could not access your account. For help, please email <a href='mailto:cul-dafeedback-l@cornell.edu'>cul-dafeedback-l@cornell.edu</a>"
        redirect_to root_path, :notice => msg.html_safe
      end
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
        # NOTE: This can also be a BD item (or ILL?) that has been checked out (system becomes Voyager
        # when that happens, at least for BD)
        if i['system'] == 'voyager' && (i['ttype'] != 'H' && i['ttype'] != 'R')
          checkouts << i
        else
          # This is a hold, recall, or ILL request. Rather than tracking the item ID, we need the request
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
          elsif i['status'] == 'chrged'
            i['status'] = 'Charged'
            checkouts << i
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
      response = RestClient.get "#{ENV['VXWS_URL']}/patron/#{patron_id(netid)}/circulationActions/debt/fines?patron_homedb=1@#{ENV['VOYAGER_DB']}"
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
      # Using the BD API is an expensive operation, so use the Rails session to cache the
      # response the first time a user accesses her account
      Rails.logger.debug "mjc12test: Checking session  #{session['mjc12_bd_items']}"
      return session[netid + '_bd_items'] if session[netid + '_bd_items']
      Rails.logger.debug "mjc12test: Can't use session value for BD items - doing full lookup #{}"

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
        if e.message.include? 'PUBAN003'
          Rails.logger.error "MyAccount error: user could not be authenticated in Borrow Direct"
        else
          raise unless e.message.include? 'PUBQR004'
        end  
        items = []
      end
      # Returns an array of BorrowDirect::RequestQuery::Item
      cleaned_items = []
      items.each do |item|
        # For the final item, we add a fake item ID number (iid) for compatibility with other items in the system
        cleaned_items << { 'tl' => item.title, 'au' => '', 'system' => 'bd', 'status' => item.request_status, 'iid' => item.request_number }
      end
      session[netid + '_bd_items'] = cleaned_items
      cleaned_items
    end

    def user
      netid = nil
      if ENV['DEBUG_USER'] && Rails.env.development?
        netid = ENV['DEBUG_USER']
      else
        netid = request.env['REMOTE_USER'] ? request.env['REMOTE_USER']  : session[:cu_authenticated_user]
      end

      netid = netid.sub('@CORNELL.EDU', '') unless netid.nil?
      netid = netid.sub('@cornell.edu', '') unless netid.nil?

      netid
    end

  end

end
