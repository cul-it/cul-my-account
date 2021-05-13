require_dependency "my_account/application_controller"

require 'rest-client'
require 'json'
require 'xmlsimple'
require 'cul/folio/edge'

module MyAccount

  class AccountController < ApplicationController
    before_action :heading
    before_action :authenticate_user, except: [:intro]

    def heading
      @heading='My Account'
    end

    def authenticate_user
      # Master disable -- this kicks the user out of My Account before anything gets going
      if ENV['DISABLE_MY_ACCOUNT']
        msg = 'My Account is currently unavailable. We apologize for the inconvenience. For more information, check the <a href="https://library.cornell.edu">CUL home page</a> for updates or <a href="https://library.cornell.edu/ask">ask a librarian</a>.'
        redirect_to "/catalog#index", :notice => msg.html_safe
        return
      end

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
      if request.headers["REQUEST_METHOD"] == "HEAD"
        head :no_content
        return
      end
      # Master disable -- this kicks the user out of My Account before anything gets going
      if ENV['DISABLE_MY_ACCOUNT']
        msg = 'My Account is currently unavailable. We apologize for the inconvenience. For more information, check the <a href="https://library.cornell.edu">CUL home page</a> for updates or <a href="https://library.cornell.edu/ask">ask a librarian</a>.'
        redirect_to "/catalog#index", :notice => msg.html_safe
      end

      @patron = get_patron_info user
      if @patron.present?
        # Take care of any requested actions first based on query params
        # if params['button'] == 'renew'
        #   Rails.logger.debug "mjc12test: Going into renew"
        #   items_to_renew = params.select { |param| param.match(/select\-.+/) }
        #   params['button'] = nil
        #   renew(user, items_to_renew) if items_to_renew.present?
        # elsif params['button'] == 'cancel'
        #   Rails.logger.debug "mjc12test: Going into cancel"
        #   items_to_cancel = params.select { |param| param.match(/select\-.+/) }
        #   cancel items_to_cancel if items_to_cancel.present?
        # end
        # # Retrieve and display account info 
        # json_response = JSON.parse(get_patron_stuff(user))
        # @checkouts = json_response['checkouts']
        # @available_requests = json_response['available']
        # @pending_requests = json_response['pending']
        # @fines = json_response['fines']
        # @bd_requests = json_response['BD']
        # # msg = json_response['message']

        if msg.length > 0
          redirect_to "/catalog#index", :notice => msg.html_safe
        end
        #   @pending_requests += @bd_requests.select{ |r| r['status'] != 'ON LOAN' && r['status'] != 'ON_LOAN' }
        #   @checkouts.sort! { |a,b| a['dueDate']  <=> b['dueDate']  } 
        #   Rails.logger.debug "mjc12test: Still going 2"

        #   # HACK: the API call that is used to build the hash of renewable (yes/no) status for checked-out
        #   # items times out with a nasty server error if the user has too many charged items. For now, arbitrarily
        #   # do this only for small collections of items. (This means that users with large collections won't see the
        #   # warning labels that certain items can't be renewed ... but the renewal process itself should still work.)
          
        #   # HACK (tlw72): if the title of a BD request = the title of an item that's checked out but shows
        #   # "voyager" as the system, it's a good bet -- maybe -- that checked out item is a BD request.
        #   # The location (lo) and callnumber (callno) of the checked out item should also be null, so
        #   # check those, too. If all three criteria meet, add a "is_bd" value to the checkout out item to grab
        #   # in the template. Also, if the system is "illiad" or there's a TransactionNumber, we have an ILL item.
        #   # add a "is_ill" value to checkout that can also be grabbed in the template.

        #   # TODO: Fix this for FOLIO
        #   # if @checkouts.length > 0
        #   #   @checkouts.each do |chk|
        #   #     if @bd_requests.length > 0
        #   #       # there's often (always?) a white space at the end of a BD title in voyager. Lose it.
        #   #       chk_title = chk["ou_title"].present? ? chk["ou_title"].sub(/\s+\Z/, "") : chk["tl"].sub(/\s+\Z/, "")
        #   #       bd_array = @bd_requests.select {|book| book["tl"] ==  chk_title}
        #   #       if bd_array.length > 0 && chk["lo"].length == 0 && chk["callno"].length == 0
        #   #         chk["is_bd"] = true
        #   #       end
        #   #     end
        #   #     if chk["system"] == "illiad" || chk["TransactionNumber"].present?
        #   #       chk["is_ill"] = true
        #   #     end
        #   #   end
        #   #   #Rails.logger.debug("tlw72 > @checkouts = " + @checkouts.inspect)          
        #   # end
          
        #   # TODO: Fix this for FOLIO
        #   # if @checkouts.length <= 100
        #   #   @renewable_lookup_hash = get_renewable_lookup user
        #   #   Rails.logger.info(@renewable_lookup_hash.inspect)
        #   # end
          
        #   # HACK: this has to follow the assignment of @checkouts so that we have the item data available for export
        #   if params['button'] == 'export-checkouts'
        #     items_to_export = params.select { |param| param.match(/select\-.+/) }
        #     export items_to_export if items_to_export.present?
        #   end
        # end
      end
    end

    # Given an array of item "ids" (of the form 'select-<id>'), return an array of the bare IDs
    # def ids_from_strings items
    #   Rails.logger.debug "mjc12test: items: #{items}"
    #   items.keys.map { |item, value| item.match(/select\-(.+)/)[1] }
    # end

    # Use one of the Voyager API to retrieve a list of checked-out items that includes a canRenew
    # property. Use this to return a lookup hash based on item ID for later use. Unfortunately, if a patron
    # has hundreds of items checked out, this can time out on the Voyager side.  
    # def get_renewable_lookup patron
    #   return nil if @patron.nil?
    #   http = Net::HTTP.new("#{ENV['MY_ACCOUNT_VOYAGER_URL']}")
    #   Rails.logger.debug "mjc12test: patron #{@patron}"
    #   url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/loans?patron_homedb=1@#{ENV['VOYAGER_DB']}"
    #   #response = RestClient.get(url)
    #   response = RestClient::Request.execute(method: :get, url: url, timeout: 120)
    #   xml = XmlSimple.xml_in response.body
    #   loans = xml['loans'] && xml['loans'][0]['institution'][0]['loan']
    #   #Rails.logger.debug "mjc12test: loans found #{loans} for xml #{xml}"
    #   ##############
    #   # loans.each do |loan|
    #   #   if (rand > 0.8)
    #   #     loan['canRenew'] = 'N'
    #   #   end
    #   # end
    #   ###############
    #   loans.map { |loan| [loan['href'][/\|(\d+)\?/,1], loan['canRenew']] }.to_h unless loans.nil?
    # end

    # Given a list of item "ids" (of the form 'select-<id>'), renew them (if possible) using the Voyager API
    # def renew netid, items
    #   Rails.logger.debug "mjc12test: Going into renew with patron info: #{@patron}"
    #   if @patron['status'] != 'Active'
    #     flash[:error] = 'There is a problem with your account. The selected items could not be renewed.'
    #   else
    #     error_messages = []
    #     # Retrieve the list of item IDs that have been selected for renewal
    #     item_ids = ids_from_strings items
    #     # if @checkouts.length <= 100 
    #     #   @renewable_lookup_hash ||= get_renewable_lookup user
    #     # end
    #     if @renewable_lookup_hash.present?
    #       renewable_item_ids = item_ids.select { |iid| @renewable_lookup_hash[iid] == 'Y' }
    #       unrenewable_item_ids = item_ids.select { |iid| @renewable_lookup_hash[iid] == 'N' }
    #     else
    #       renewable_item_ids = item_ids
    #       unrenewable_item_ids = []
    #     end
    #     # if params['num_checkouts'] && renewable_item_ids.length == params['num_checkouts'].to_i
    #     #   renew_all
    #     # else
    #     Rails.logger.debug "mjc12test: renewable item_ids #{renewable_item_ids}"
    #     Rails.logger.debug "mjc12test: unrenewable item_ids #{unrenewable_item_ids}"

    #     # Invoke Voyager APIs to do the actual renewals
    #     errors = false
    #     successful_renewal_count = 0
    #     renewable_item_ids.each do |id|
    #       # Check for ILLiad item
    #       if id.start_with? 'illiad'
    #         transaction_id = id.split(/-/)[1]
    #         response = RestClient.get "https://ill-access.library.cornell.edu/illrenew.cgi?netid=#{@patron['netid']}&iid=#{transaction_id}"
    #         response = JSON.parse response.body
    #         Rails.logger.debug "mjc12test: got renew response: #{response['error']}"
    #         if response['error'].present?
    #           error_messages << "Could not renew item in ILLiad"
    #           Rails.logger.error "My Account: Couldn't renew ILLiad item with transaction ID #{transaction_id}. Request returned error: #{response['error']}"
    #           errors = true
    #         else
    #           successful_renewal_count += 1
    #         end
    #       else
    #         url = ENV['OKAPI_URL']
    #         tenant = ENV['OKAPI_TENANT']
    #         token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])
    #        # Rails.logger.debug("mjc12test: Got FOLIO token #{token}")
    #         response = CUL::FOLIO::Edge.renew_item(url, tenant, token[:token], netid, id)
    #         # http = Net::HTTP.new("#{ENV['MY_ACCOUNT_VOYAGER_URL']}")
    #         # url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/loans/1@#{ENV['VOYAGER_DB']}%7C#{id}?patron_homedb=1@#{ENV['VOYAGER_DB']}"
    #         Rails.logger.debug "mjc12test: Trying to renew with url: #{url}, tenant: #{tenant}"
    #         # response = CUL::FOLIO::Edge.renew_item()
    #         # response = RestClient.post(url, {})
    #         Rails.logger.debug("mjc12test: renew response: #{response}")
    #         # xml = XmlSimple.xml_in response.body
    #         # Rails.logger.debug "mjc12test: response #{xml}"
    #         if response[:code] > 201
    #           error_messages << "Item could not be renewed due to an error."
    #           Rails.logger.error "My Account: couldn't renew item #{id}. API returned: #{response[:error]}"
    #           errors = true                
    #         else  
    #           successful_renewal_count += 1
              
    #           # response_loan_info = xml && xml['renewal'][0]['institution'][0]['loan'][0] 
    #         end
    #         # if xml && xml['reply-code'][0] != '0' 
    #         #   error_messages << "Item '#{response_loan_info['title'][0]}' could not be renewed due to an error:  " + xml['reply-text'][0]
    #         #   Rails.logger.error "My Account: couldn't renew item #{id}. XML returned: #{xml}"
    #         #   errors = true
    #         # elsif response_loan_info && response_loan_info['renewalStatus'][0] != 'Success' 
    #         #   error_messages << "Item '#{response_loan_info['title'][0]}' could not be renewed due to an error: " + response_loan_info['renewalStatus'][0]
    #         #   Rails.logger.error "My Account: couldn't renew item #{id}. XML returned: #{xml}"
    #         #   errors = true
    #         # else
    #         # end
    #       end
    #       # end

    #       if renewable_item_ids.count == 1 && successful_renewal_count == 1 && errors == false
    #         flash[:notice] = 'This item has been renewed.'
    #       elsif successful_renewal_count > 1
    #         flash[:notice] = "#{successful_renewal_count} items were renewed."
    #       end
    #       if unrenewable_item_ids.count > 0
    #         error_messages << 'Some items were skipped because they could not be renewed. Ask a librarian for more information.'
    #       end
    #       if error_messages.present?
    #         error_messages = error_messages.join('<br/>').html_safe
    #         flash[:error] = error_messages 
    #       end
    #     end
    #     params.select! { |param| !param.match(/select\-.+/) }
    #   end
    # end

    # Use the CUL::FOLIO::Edge gem to renew an item. Operation is triggered via AJAX.
    def ajax_renew
      netid = params['netid']
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])
      # Rails.logger.debug("mjc12test: Got FOLIO token #{token}")
      result = CUL::FOLIO::Edge.renew_item(url, tenant, token[:token], netid, params['itemId'])
      # Rails.logger.debug("mjc12test: Got FOLIO result #{result.inspect}")
      render json: result
    end

    # def renew_all
    #   Rails.logger.debug "mjc12test: Renewing all!"
    #   http = Net::HTTP.new("#{ENV['MY_ACCOUNT_VOYAGER_URL']}")
    #   url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/loans?institution=1@LOCAL&patron_homedb=1@#{ENV['VOYAGER_DB']}"
    #   response = RestClient.post(url, {})
    #   xml = XmlSimple.xml_in response.body
    #     Rails.logger.debug "mjc12test: response from renew all: #{xml}"
    #   if xml && xml['reply-code'][0] != '0'
    #     flash[:error] = "There was an error when trying to renew all items: " + xml['reply-text'][0]
    #     Rails.logger.error "My Account: couldn't renew all items. XML returned: #{xml}"
    #   else
    #     flash[:notice] = 'All items were renewed.'
    #   end
    # end

    # Given a list of item "ids" (of the form 'select-<id>'), cancel them (if possible)
    # Requested items could be Voyager items, ILLiad, or Borrow Direct -- so use whichever API is appropriate
    def cancel items
      # For cancellation the param value contains the ttpe, so build a hash to reference in the loop below.
      id_hash = items.transform_keys{ |k| k.gsub("select-","") }
      request_ids = ids_from_strings items
      Rails.logger.debug "mjc12test: items to cancel #{request_ids}"
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
          # What's the ttype? Call slips get a different url than holds and recalls.
          url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/requests/callslips/1@#{ENV['VOYAGER_DB']}%7C#{id}?patron_homedb=1@#{ENV['VOYAGER_DB']}" if id_hash[id] == "C"
          # Remember that Voyager uses the '/holds/' path for both holds and recalls in order to confuse us
          url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/requests/holds/1@#{ENV['VOYAGER_DB']}%7C#{id}?patron_homedb=1@#{ENV['VOYAGER_DB']}" if id_hash[id] != "C"
          response = RestClient.delete(url, {})
        end
      end

      if request_ids.count == 1
        flash[:notice] = 'Your request has been cancelled.'
      elsif request_ids.count > 1
        flash[:notice] = 'Your requests have been cancelled.'
      end

    end

    # def export items
    #   item_ids = ids_from_strings items
    #   ris_output = ''
    #   item_ids.each do |id|
    #     record = @checkouts.detect { |i| i['item']['itemId'] == id }
    #     # TODO: the TY field may need to be made dynamic to account for different material types -
    #     # see https://en.wikipedia.org/wiki/RIS_(file_format). But currently the item record passed in
    #     # does not indicate type.
    #     if record['item']
    #       item = record['item']
    #       ris_output += "TY  - BOOK\n"
    #       # ris_output += "CY  - #{item['ou_pp']}\n"
    #       # ris_output += "PY  - #{item['ou_yr']}\n"
    #       # ris_output += "PB  - #{item['ou_pb']}\n"
    #       # ris_output += "T1  - #{item['ou_title']}\n"
    #       ris_output += "T1  - #{item['title']}\n" if item['title']
    #       # ris_output += "AU  - #{item['au']}\n"
    #       ris_output += "AU  - #{item['author']}\n" if item['author']
    #       # ris_output += "SN  - #{item['ou_isbn']}\n"
    #       # LA  - English
    #       # ris_output += "UR  - http://newcatalog.library.cornell.edu/catalog/#{item['bid']}\n"
    #       # ris_output += "CN  - #{item['callno']}\n"
    #       ris_output += "ER  -\n"
    #     end
    #   end

    #   send_data ris_output, filename: 'citation.ris', type: 'text/ris'
    # end

    # def get_patron_info netid
    #   response = RestClient.get "#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}"
    #   record = JSON.parse response.body
    #   record[netid]
    # end

    # DEPRECATED
    # This is the main lookup function. It retrieves a list of a user's requests and charged
    # items using the ilsapi CGI script.
    # DISCOVERYACCESS-5558 add msg for the error handling
    #
    # Account information (Voyager, BD, ILL) was provided by the ilsapiE.cgi script. Besides a
    # 'patron' JSON object, it provided an 'items' array. Each item is an object representing an
    # item from Voyager, ILL, or Borrow Direct.
    # For the move to FOLIO, we use the EdgePatron API to look up a user's account info, which comes
    # back (via the CUL FOLIO Edge gem) looking like this:
    # { :account=>
    #     {"totalCharges"=>
    #       {"amount"=>0.0, "isoCurrencyCode"=>"USD"}, 
    #       "totalChargesCount"=>0, 
    #       "totalLoans"=>2, 
    #       "totalHolds"=>0, 
    #       "charges"=>[], 
    #       "holds"=>[], 
    #       "loans"=>[
    #         {"id"=>"c6ce747e-e210-4eb7-a72d-ea7116e803b4",
    #          "item"=>{
    #            "instanceId"=>"69640328-788e-43fc-9c3c-af39e243f3b7", 
    #            "itemId"=>"eedd13c4-7d40-4b1e-8f77-b0b9d19a896b", 
    #            "title"=>"ABA Journal"}, 
    #          "loanDate"=>"2021-03-19T14:42:32.000+0000", 
    #          "dueDate"=>"2021-05-18T23:59:59.000+0000", 
    #          "overdue"=>false}, 
    #         {"id"=>"c372ee00-a89f-4d9c-ba8a-9316fe43e47e", 
    #           "item"=>{"instanceId"=>"cf23adf0-61ba-4887-bf82-956c4aae2260", 
    #             "itemId"=>"88d326f0-5d94-4c00-a497-7fefebbd724a",
    #             "title"=>"Temeraire", 
    #             "author"=>"Novik, Naomi"}, 
    #           "loanDate"=>"2021-03-19T14:42:56.000+0000", 
    #           "dueDate"=>"2021-03-19T15:42:56.000+0000", 
    #           "overdue"=>false}
    #       ]
    #     }, 
    #   :error=>nil, 
    #   :code=>200
    # } 
    #
    # If we assume that ilsapiE.cgi is rewritten to *only* return ILL results, then that simplifies the
    # parsing below greatly. No need to try to figure out whether something is a charged item or a request
    def get_illiad_data
      record = nil
      msg = ""

      netid = params['netid']
      # folio_account_data = get_folio_accountinfo netid
      Rails.logger.debug "mjc12test: Start parsing"

      begin 
        response = RestClient.get "#{ENV['MY_ACCOUNT_ILSAPI_URL']}?netid=#{netid}"
        record = JSON.parse response.body
      rescue => error
        Rails.logger.error "MyAccount error: Could not find a patron entry for #{netid}"
        msg = "We're sorry, but we could not access your account. For help, please email <a href='mailto:cul-dafeedback-l@cornell.edu'>cul-dafeedback-l@cornell.edu</a>"
        return [nil, nil, nil, nil, nil, msg]
      end

      # checkouts = folio_account_data[:account]['loans']
      pending_requests = []
      available_requests = []

      # Parse the results of the ilsapiE/ILLiad lookup. Loans (from FOLIO) are handled separately
      record['items'].each do |i|
        # TODO: items returned with a status of 'finef' appear to be duplicates, only
        # indicating that a fine or fee is applied to that item. So we don't need them
        # in this list? But maybe check the fine-related functions below to see if we
        # need to do anything with this
        # TODO 2: Is this still relevant with FOLIO? Can ILL items have this status?
        next if i['status'] == 'finef'

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
          # If the due date is an empty string, this line in the haml file throws an exception:
          # c['DueDate']).to_date.strftime('%m/%d/%y'). (DISCOVERYACCESS-5822)
          if i['DueDate'] == ''
            i['DueDate'] = nil
          end
          available_requests << i
        elsif i['status'] == 'chrged'
          # TODO: Is this still relevant with FOLIO? Can an ILL item have this status?
          i['status'] = 'Charged'
          # checkouts << i
        else
          pending_requests << i
        end
      end

      Rails.logger.debug "mjc12test: Done with parsing"

      bd_items = get_bd_requests netid

      render json: { pending: pending_requests, available: available_requests }
    end

    # Use the FOLIO EdgePatron API to retrieve a user's account information. This provides lists of checkouts/
    # charged items and fines/fees. This is called by AJAX, so the result is handled there as well.
    def get_folio_data
      netid = params['netid']
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])
     # Rails.logger.debug("mjc12test: Got FOLIO token #{token}")
      account = CUL::FOLIO::Edge.patron_account(url, tenant, token[:token], {:username => netid})
     # Rails.logger.debug("mjc12test: Got FOLIO account #{account.inspect}")
      render json: account
    end

    # Render the _checkouts partial in response to an AJAX call
    def ajax_checkouts
      @checkouts = params['checkouts']&.values.to_a
      render json: { record: render_to_string('_checkouts', :layout => false), locals: { checkouts: @checkouts }}
    end

    # Render the _checkouts partial in response to an AJAX call
    def ajax_fines
      @fines = params['fines']&.values.to_a
      render json: { record: render_to_string('_fines', :layout => false), locals: { fines: @fines }}
    end

    # Render the _available_requests partial in response to an AJAX call
    def ajax_illiad_available
      @available_requests = params['requests']&.values.to_a
      render json: { record: render_to_string('_available_requests', :layout => false), locals: { available_requests: @available_requests }}
    end

    # Render the _pending_requests partial in response to an AJAX call
    def ajax_illiad_pending
      @pending_requests = params['requests']&.values.to_a
      render json: { record: render_to_string('_pending_requests', :layout => false), locals: { pending_requests: @pending_requests }}
    end

    # TODO: Replace with FOLIO
    def patron_id(netid)
      response = RestClient.get "#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}"
      record = JSON.parse(response.body)
      record[netid]['patron_id']
    rescue
      Rails.logger.debug("tlw72 ****** could not retrieve patron id.")
      return ""
    end

    # TODO: Replace with FOLIO
    def patron_barcode(netid)
      response = RestClient.get "#{ENV['MY_ACCOUNT_PATRONINFO_URL']}/#{netid}"
      record = JSON.parse(response.body)
      record[netid]['barcode']
    rescue
      Rails.logger.debug("tlw72 ****** could not retrieve patron barcode.")
      return ""
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
          # TODO: Add better error handling. For now, BD is causing too many problems with flaky connections;
          # we have to do something other than raise the errors here.
          # raise unless e.message.include? 'PUBQR004'
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
