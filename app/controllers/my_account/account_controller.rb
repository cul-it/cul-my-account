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

      @netid = user
    end

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

    # Given a list of item "ids" (of the form 'select-<id>'), cancel them (if possible)
    # Requested items could be Voyager items, ILLiad, or Borrow Direct -- so use whichever API is appropriate
    # def cancel items
    #   # For cancellation the param value contains the ttpe, so build a hash to reference in the loop below.
    #   id_hash = items.transform_keys{ |k| k.gsub("select-","") }
    #   request_ids = ids_from_strings items
    #   Rails.logger.debug "mjc12test: items to cancel #{request_ids}"
    #   request_ids.each do |id|
    #     if id.match(/^COR/)
    #       # TODO: implement this
    #       # do a Borrow Direct cancel
    #     elsif id.match(/^illiad/)
    #       # TODO: implement this
    #       # do an ILLiad cancel
    #     else
    #       # do a Voyager cancel
    #       http = Net::HTTP.new("#{ENV['MY_ACCOUNT_VOYAGER_URL']}")
    #       # What's the ttype? Call slips get a different url than holds and recalls.
    #       url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/requests/callslips/1@#{ENV['VOYAGER_DB']}%7C#{id}?patron_homedb=1@#{ENV['VOYAGER_DB']}" if id_hash[id] == "C"
    #       # Remember that Voyager uses the '/holds/' path for both holds and recalls in order to confuse us
    #       url = "#{ENV['MY_ACCOUNT_VOYAGER_URL']}/patron/#{@patron['patron_id']}/circulationActions/requests/holds/1@#{ENV['VOYAGER_DB']}%7C#{id}?patron_homedb=1@#{ENV['VOYAGER_DB']}" if id_hash[id] != "C"
    #       response = RestClient.delete(url, {})
    #     end
    #   end

    #   if request_ids.count == 1
    #     flash[:notice] = 'Your request has been cancelled.'
    #   elsif request_ids.count > 1
    #     flash[:notice] = 'Your requests have been cancelled.'
    #   end

    # end 
    
    # Use the CUL::FOLIO::Edge gem to cancel a request. Operation is triggered via AJAX.
    def ajax_cancel
      netid = params['netid']
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])
      result = CUL::FOLIO::Edge.cancel_request(url, tenant, token[:token], netid, params['requestId'])

      render json: result
    end

    # Retrieves a list of a user's requests and charged items using the ilsapi CGI script.
    # DISCOVERYACCESS-5558 add msg for the error handling
    #
    # Account information (Voyager, BD, ILL) was provided by the ilsapiE.cgi script. Besides a
    # 'patron' JSON object, it provided an 'items' array. Each item is an object representing an
    # item from Voyager, ILL, or Borrow Direct.
    # If we assume that ilsapiE.cgi is rewritten to *only* return ILL results, then that simplifies the
    # parsing below greatly. No need to try to figure out whether something is a charged item or a request
    def get_illiad_data
      record = nil
      msg = ""

      netid = params['netid']
      # folio_account_data = get_folio_accountinfo netid
      # Rails.logger.debug "mjc12test: Start parsing"

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

    # Use the FOLIO EdgePatron API to retrieve a user's user record from FOLIO (*not* the user's account,
    # which here refers to his/her checkouts and fines/fees). 
    def get_user_record
      netid = params['netid']
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])
     # Rails.logger.debug("mjc12test: Got FOLIO token #{token}")
      user = CUL::FOLIO::Edge.patron_record(url, tenant, token[:token], netid)
     # Rails.logger.debug("mjc12test: Got FOLIO user #{user.inspect}")
      render json: user
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

    # Use the FOLIO gem to retrieve an instance's HRID (i.e., bib id) given its UUID. Token is included
    # as a parameter so that calling this repeatedly in a loop doesn't incur multiple authentication calls
    def ajax_catalog_link
      instanceId = params['instanceId']
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      token = params['token'] || CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])[:token]
      # Get instance HRID (e.g., bibid) for the record
      response = CUL::FOLIO::Edge.instance_record(url, tenant, token, instanceId)
      link = nil
      if response[:code] < 300
        link = "https://newcatalog.library.cornell.edu/catalog/#{response[:instance]['hrid']}"
      end
      #Rails.logger.debug "mjc12test: got response #{response[:instance]['hrid']} for #{instanceId} with link #{link}"
      render json: { link: link }
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
