require_dependency "my_account/application_controller"

require 'rest-client'
require 'json'
require 'xmlsimple'
require 'cul/folio/edge'

module MyAccount

  class AccountController < ApplicationController
    #include Reshare

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

      #Rails.logger.debug "mjc12test: authenticating"
      if user.present?
        index
      else
        session[:cuwebauth_return_path] = myaccount_path
        if ENV['DEBUG_USER'] && Rails.env.development?
          index
        else
          # Omniauth gem requirements
          uri = URI(request.original_url)
          scheme_host = "#{uri.scheme}://#{uri.host}"
          if uri.port.present? && uri.port !=  uri.default_port()
            scheme_host = scheme_host + ':' + uri.port.to_s
          end
          redirect_post("#{scheme_host}/users/auth/saml", options: {authenticity_token: :auto})
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

      # Check for alert messages in alerts.yaml
      begin
        alert_messages = YAML.load_file("#{Rails.root}/alerts.yaml")
        # Each message in the YAML file should have a pages array that lists which pages (e.g., MyAccount, Requests)
        # should show the alert, and a message property that contains the actual message text/HTML. Only show
        # the messages for the proper page.
        @alerts = alert_messages.select{|m| m['pages']&.include?('MyAccount')}.map{|m| m['message']}
      rescue Errno::ENOENT, Psych::SyntaxError
        # Nothing to do here; the alerts file is optional, and its absence (Errno::ENOENT) just means that there
        # are no alert messages to show today. Psych::SyntaxError means there was an error in the syntax
        # (most likely the indentation) of the YAML file. That's not good, but crashing with an ugly
        # error message is worse than not showing the alerts.
      end
    end

    # Return a FOLIO authentication token for API calls -- either from the session if a token
    # was prevoiusly created, or directly from FOLIO otherwise.
    def folio_token
      if session[:folio_token].nil?
        Rails.logger.debug "mjc12test6: creating new token"
        url = ENV['OKAPI_URL']
        tenant = ENV['OKAPI_TENANT']
        response = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])
        if response[:code] >= 300
          Rails.logger.error "MyAccount error: Could not create a FOLIO token for #{netid}"
        else
          session[:folio_token] = response[:token]
        end
      end
      session[:folio_token]
    end

    # Use the CUL::FOLIO::Edge gem to renew an item. Operation is triggered via AJAX.
    def ajax_renew
      netid = params['netid']
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      result = CUL::FOLIO::Edge.renew_item(url, tenant, folio_token, netid, params['itemId'])
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
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      # NOTE: The cancel_reason value set below is the UUID of the current 'Patron Cancelled'
      # request cancellation reason in FOLIO. Hard-coding it here is risky if that value ever changes,
      # but the alternative would be to do a secondary call to 
      # /cancellation-request-storage/cancellation-reasons and then parse out the correct reason
      # by text matching -- also a risky proposition.
      cancel_reason = 'ba60fd97-adcf-406e-97aa-6bf5e2a6243d'

      result = CUL::FOLIO::Edge.cancel_request(url, tenant, folio_token, params['requestId'], cancel_reason)

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

      #bd_items = get_bd_requests netid
      bd_items = []
      #Rails.logger.debug "mjc12test: got bd_items #{bd_items}"

      render json: { pending: pending_requests, available: available_requests }
    end

    # Use the FOLIO EdgePatron API to retrieve a user's user record from FOLIO (*not* the user's account,
    # which here refers to his/her checkouts and fines/fees). 
    def get_user_record
      netid = params['netid']
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      user = CUL::FOLIO::Edge.patron_record(url, tenant, folio_token, netid)
      Rails.logger.debug("mjc12test6: Got FOLIO user #{user.inspect}")
      render json: user
    end

    # Use the FOLIO EdgePatron API to retrieve a user's account information. This provides lists of checkouts/
    # charged items and fines/fees. This is called by AJAX, so the result is handled there as well.
    def get_folio_data
      netid = params['netid']
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      account = CUL::FOLIO::Edge.patron_account(url, tenant, folio_token, {:username => netid})
     # Rails.logger.debug("mjc12test: Got FOLIO account #{account.inspect}")
      render json: account
    end

    # Render the _checkouts partial in response to an AJAX call
    def ajax_checkouts
      @checkouts = params['checkouts']&.values.to_a
      #@checkouts.sort_by! { |c| Date.parse(c['dueDate']) }
      render json: { record: render_to_string('_checkouts', :layout => false), locals: { checkouts: @checkouts }}
    end

    # Retrieve a service point record from FOLIO
    def ajax_service_point
      sp_id = params['sp_id']
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      sp = CUL::FOLIO::Edge.service_point(url, tenant, folio_token, sp_id)
      render json: sp
    end

    # Use the FOLIO gem to retrieve an instance's HRID (i.e., bib id) and source, given its UUID. Token is included
    # as a parameter so that calling this repeatedly in a loop doesn't incur multiple authentication calls. The
    # source is needed later to derermine whether this is a BD or ILL or FOLIO item.
    def ajax_catalog_link_and_source
      instanceId = params['instanceId']
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      # Get instance HRID (e.g., bibid) for the record
      response = CUL::FOLIO::Edge.instance_record(url, tenant, folio_token, instanceId)
      link = nil
      source = nil
      if response[:code] < 300
        source = response[:instance]['source']
        # Ignore Borrow Direct records for the link -- they have an HRID that looks like a legit bibid, but
        # it's something else BD-related. We can't link to those.
        if source != 'bd'
          link = "https://newcatalog.library.cornell.edu/catalog/#{response[:instance]['hrid']}"
        end
      end
      render json: { link: link, source: source }
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

    def get_bd_requests
      netid = params['netid']

      # Using the BD API is an expensive operation, so use the Rails session to cache the
      # response the first time a user accesses her account
      Rails.logger.debug "mjc12a: Checking session  #{session['mjc12_bd_items']}"
      #return session[netid + '_bd_items'] if session[netid + '_bd_items']
      Rails.logger.debug "mjc12test: Can't use session value for BD items - doing full lookup #{}"

      #barcode = patron_barcode(netid)

      # Set parameters for the Borrow Direct API
      # BorrowDirect::Defaults.library_symbol = 'CORNELL'
      # BorrowDirect::Defaults.find_item_patron_barcode = barcode
      # BorrowDirect::Defaults.timeout = ENV['BORROW_DIRECT_TIMEOUT'].to_i || 30 # (seconds)
      # BorrowDirect::Defaults.api_base = BorrowDirect::Defaults::PRODUCTION_API_BASE
      # BorrowDirect::Defaults.api_key = ENV['BORROW_DIRECT_PROD_API_KEY']

      begin
        tenant = 'cornell'
        token = nil
        response = CUL::FOLIO::Edge.authenticate(ENV['RESHARE_STATUS_URL'], tenant, 'mjc12@cornell.edu', 'maiSyl4RS!')
        if response[:code] >= 300
          Rails.logger.error "MyAccount error: Could not create a ReShare token for #{netid}"
        else
          token = response[:token]
        end
        # Note that the match/term query parameters are apparently undocumented in the APIs, but
        # that's what ReShare is using internally to filter results in its apps.
        url = "#{ENV['RESHARE_STATUS_URL']}/rs/patronrequests?match=patronIdentifier&term=#{netid}&perPage=1000"
        headers = {
          'X-Okapi-Tenant' => 'cornell',
          'x-okapi-token' => token,
          :accept => 'application/json',
        }
        response = RestClient.get(url, headers)
        # TODO: check that response is in the proper form and there are no returned errors
        items = JSON.parse(response)
        #Rails.logger.debug "mjc12a: got BD results #{items}"
     rescue RestClient::Exception => e
       # items = BorrowDirect::RequestQuery.new(barcode).requests('open')
      # rescue BorrowDirect::Error => e
      #   # The Borrow Direct gem doesn't differentiate among all of the BD API error types.
      #   # In this case, PUBQR004 is an exception raised when there are no results for the query
      #   # (why should that cause an exception??). We don't want to crash and burn just because
      #   # the user doesn't have any BD requests in the system. But if it's anything else,
      #   # raise it again -- that indicates a real problem.
      #   if e.message.include? 'PUBAN003'
      #     Rails.logger.error "MyAccount error: user could not be authenticated in Borrow Direct"
      #   else
      #     # TODO: Add better error handling. For now, BD is causing too many problems with flaky connections;
      #     # we have to do something other than raise the errors here.
      #     # raise unless e.message.include? 'PUBQR004'
      #   end  
        items = []
        Rails.logger.debug "mjc12a: BIG ERROR: #{e}"
        Rails.logger.error 'MyAccount error: Couldn\'t retrieve patron requests from Borrow Direct.'
      end
      # Returns an array of BorrowDirect::RequestQuery::Item
      cleaned_items = []
      items.each do |item|
        Rails.logger.debug "mjc12a: item data: HRID: #{item['hrid']} for patronIdentifier #{item['patronIdentifier']}"
        Rails.logger.debug "mjc12a: state: #{item['state']['code']}, stage: #{item['state']['stage']}"

        # HACK: This is a terrible way to obtain the item title. Unfortunately, this information isn't surfaced
        # in the API response, but only provided as part of a marcxml description of the entire item record.
        marc = XmlSimple.xml_in(item['bibRecord'])
        f245 = marc['GetRecord'][0]['record'][0]['metadata'][0]['record'][0]['datafield'].find {|t| t['tag'] == '245'}
        f245a = f245['subfield'].find { |sf| sf['code'] == 'a' }
        f245b = f245['subfield'].find { |sf| sf['code'] == 'b' }
        title = f245b ? "#{f245a['content']} #{f245b['content']}" : f245a['content']

        # For the final item, we add a fake item ID number (iid) for compatibility with other items in the system
        # ReShare status *stages* are defined here: 
        # https://github.com/openlibraryenvironment/mod-rs/blob/master/service/src/main/groovy/org/olf/rs/statemodel/StatusStage.groovy
        # and *states* are here:
        # https://github.com/openlibraryenvironment/mod-rs/blob/master/doc/states.md
        # I think we only need to worry about stage to distinguish between pending and available.
        cleaned_items << { 'tl' => title, 'au' => '', 'system' => 'bd', 'status' => item['state']['stage'], 'iid' => item['hrid'] }
      end
      session[netid + '_bd_items'] = cleaned_items
      Rails.logger.debug "mjc12a: cleaned BD items: #{cleaned_items}"
      render json: cleaned_items
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
