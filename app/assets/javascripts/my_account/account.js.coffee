$(document).ready ->
  account.onLoad()

account =
  onLoad: () ->

    # Handle display of flash messages
    $(document).ajaxComplete (event, request) ->
      account.ajaxComplete(event, request)

    # Main data loading section
    netid = $('#accountData').data('netid')

    # Query the FOLIO edge-patron API to retrieve user's checkouts and fines/fees.
    # The account object is passed along to separate handlers to process each
    # type of data individually.
    folioAccountLookup = $.ajax({
      url: "/myaccount/get_folio_data"
      type: "POST"
      data: { netid }
      success: (data) ->
        if data.code < 300
          account.showCheckouts(data)
          account.showFines(data)
    })

    # Query the ILLiad CGI scripts to retrieve user's item requests
    illiadAccountLookup = $.ajax({
      url: "/myaccount/get_illiad_data"
      type: "POST"
      data: { netid }
    })

    # FOLIO account data is needed for both the checkouts pane and the requests panes. Requests in FOLIO
    # have to be combined with requests from ILLiad and BD, though, which takes a bit of manipulation.
    # So we use .when() here to do both lookups before proceeding
    $.when(folioAccountLookup, illiadAccountLookup).done (folioAccount, illiadAccount) ->
      if folioAccount[0].code > 200
        console.log("MyAccount error: couldn't retrieve user account data from FOLIO (#{folioAccount[0].error})")
        $("#checkouts").html("<span>Couldn't retrieve account information. Please ask a librarian for assistance.</span>")
      if illiadAccount[0] == undefined
        console.log("MyAccount error: couldn't retrieve user account data from ILLiad")
      account.showRequests(folioAccount[0].account.holds, illiadAccount[0])
      .then () ->
        #account.setEvents()
    (error) ->
      console.log("MyAccount error in combining account lookup results (#{error})")

    # Enable tab navigation
    $('.nav-tabs a').click ->
      $(this).tab('show')
      account.setActionButtonState()

    # Look up user's name from FOLIO
    $.ajax({
      url: "/myaccount/get_user_record"
      type: "POST"
      data: { netid: netid }
      error: (jqXHR, textStatus, error) -> 
        console.log("MyAccount error: couldn't retrieve user record from FOLIO for #{netid} (#{error})")
      success: (data) ->
        nameSection = data.user.personal
        $('#userName').html("Account information for #{nameSection['firstName']} #{nameSection['lastName']}")
    })

  ######### END OF ONLOAD FUNCTION ###########

  # Enable or disable the action buttons for the current open tab
  # based on whether any items are selected in that tab
  setActionButtonState: () ->
    activeTab = $('.tab-pane.active').attr('id')
    buttonsDisabled = $('#' + activeTab + ' input:checkbox:checked').length < 1
    console.log("ButtonsDisabled", buttonsDisabled, activeTab)

    if (activeTab == 'checkouts')
      $('#renew').prop('disabled', buttonsDisabled)
    else if (activeTab == 'pending-requests')
      console.log("settitng button", buttonsDisabled)
      $('#cancel').prop('disabled', buttonsDisabled)

  setEventHandlers: () ->
    # Select/deselect all checkboxes when clicked
    $("input:checkbox.select-all").click ->
      checked = $(this).prop('checked')
      $('tr.item input:checkbox').prop('checked', checked)
      account.setActionButtonState()

    # Enable/disable action buttons if any checkbox is selected
    $("input:checkbox").click ->
      account.setActionButtonState()

    # Renew button
    $('#renew').click ->
      $('#request-loading-spinner').spin('renewing')
      account.renewItems()

    # Cancel button
    $('#cancel').click ->
      $('#request-loading-spinner').spin('cancelling')
      account.cancelItems()

  # Populate checkouts in the UI
  showCheckouts: (accountData) ->
    $.ajax({
      url: "/myaccount/ajax_checkouts"
      type: "POST"
      data: { checkouts: accountData.account.loans }
      error: (jqXHR, textStatus, error) ->
        console.log("MyAccount error: couldn't render checkouts template (#{error})")
      success: (data) ->
        $("#checkouts").html(data.record)
        $('#checkoutsTab').html('Checked out (' + data.locals.checkouts.length + ')')
        # Add catalog links to the titles in the table
        data.locals.checkouts.forEach (checkout) ->
          account.addCatalogLink(checkout)
        account.setActionButtonState()
        account.setEventHandlers()
    })

  # Given a checkout entry, call an ajax method to determine its instance bibid
  # and create a link to the catalog record, then add the link to the displayed title
  addCatalogLink: (entry) ->
    $.ajax({
      url: "/myaccount/ajax_catalog_link"
      type: "POST"
      data: { instanceId: entry.item.instanceId }
      error: (jqXHR, textStatus, error) ->
        console.log("MyAccount error: couldn't add catalog link for #{entry.id} (#{error})")
      success: (data) ->
        # Find the correct item title and add the link
        title = $("##{entry.item.itemId} .title").html()
        $("##{entry.item.itemId} .title").html("<a href='#{data.link}'>#{title}</>")
    })

  # Populate fines/fees in the UI
  showFines: (accountData) ->
    $.ajax({
      url: "/myaccount/ajax_fines"
      type: "POST"
      data: { fines: accountData.account.charges }
      error: (jqXHR, textStatus, error) ->
        console.log("MyAccount error: couldn't render fines template (#{error})")
      success: (data) ->
        fineTotal = '$' + accountData.account.totalCharges.amount
        $('#fines').html(data.record)
        $('#finesTab').html('Fines and fees (' + fineTotal + ')')
    })

  # Populate requests in the UI
  showRequests: (folioData, illiadData) ->
    # Combine ILLiad requests and FOLIO requests into the same arrays
    available = illiadData.available
    pending = illiadData.pending
    folioData.forEach (entry) ->
      requestObj = {
        iid: entry.requestId, # N.B. The ID used here for FOLIO requests is the REQUEST ID, not the item ID!
        tl: entry.item.title,
        lo: entry.pickupLocationId,
        requestDate: entry.requestDate
      }
      # This is a weak way of determining available/pending status. Come up with something better?
      if entry.status.match /^Open/
        pending.push requestObj
      else
        available.push requestObj

    # Available requests tab
    $.ajax({
      url: "/myaccount/ajax_illiad_available"
      type: "POST"
      data: { requests: available }
      error: (jqXHR, textStatus, error) ->
        console.log("MyAccount error: couldn't render available requests template (#{error})")
      success: (data) ->
        $('#available-requests').html(data.record)
        $('#availableTab').html('Ready for pickup (' + data.locals.available_requests.length + ')')
        account.setActionButtonState()
        account.setEventHandlers()
    })
    # Pending requests tab
    $.ajax({
      url: "/myaccount/ajax_illiad_pending"
      type: "POST"
      data: { requests: pending }
      error: (jqXHR, textStatus, error) ->
        console.log("MyAccount error: couldn't render pending requests template (#{error})")
      success: (data) ->
        $("#pending-requests").html(data.record)
        $('#pendingTab').html('Pending requests (' + data.locals.pending_requests.length + ')')
        account.setActionButtonState()
        account.setEventHandlers()
    })

  renewItems: () ->
    netid = $('#accountData').data('netid')
    ids = []
    $('#checkouts input:checked').each () -> ids.push(this.id)

    # HACK - trim off the first array item if it doesn't contain an ID (it's the 'select all' checkbox)
    ids.shift() if ids[0] == ''

    promises = []
    ids.forEach (id) ->
      promises.push(account.renewItem(netid, id).catch (error) -> return error)

    Promise.all(promises)
      .then (result) ->
        errors = result.filter (r) -> r.error
        if errors != []
          account.setFlash('alert-success', "Some items could not be renewed")
        else
          account.setFlash('alert-success', "Renewal succeeded")
        $('#request-loading-spinner').spin(false)
      .catch (error) ->
        account.setFlash('alert-success', "Some items could not be renewed")
        $('#request-loading-spinner').spin(false)

  # Return a promise that renews a single item
  renewItem: (netid, id) ->
    new Promise (resolve, reject) =>
      $.ajax({
        url: "/myaccount/ajax_renew"
        type: "POST"
        data: { netid: netid, itemId: id }
        error: (jqXHR, textStatus, error) ->
          console.log("MyAccount error: Unable to renew item #{id} (#{error})")
          account.updateItemStatus(id, { code: 400 })
          reject new Error("Sending an error 2")
        success: (result) ->
          # N.B. This operation succeeds if the CUL::FOLIO::Edge gem returns a response correctly.
          # That does not mean that *renewal* has succeeded; for that, check the response code
          # in result
          account.updateItemStatus(id, result)
          if result.code < 300
            resolve result
          else
            reject result
      })

  cancelItems: () ->
    netid = $('#accountData').data('netid')
    ids = []
    $('#pending-requests input:checked').each () -> ids.push(this.id)

    # HACK - trim off the first array item if it doesn't contain an ID (it's the 'select all' checkbox)
    ids.shift() if ids[0] == ''

    promises = []
    ids.forEach (id) ->
      promises.push(account.cancelRequest(netid, id).catch (error) -> return error)

    Promise.all(promises)
      .then (result) ->
        errors = result.filter (r) -> r.error
        if errors != []
          # TODO: This should display an error, obviously. But because of the duplicate requests bug,
          # even successful cancel operations can appear to fail (because they're run a second time
          # against a request that no longer exists). Thus, a vague response for now.
          account.setFlash('alert-success', "Cancellation complete")
        else
          account.setFlash('alert-success', "Cancellation complete")
        $('#request-loading-spinner').spin(false)
        # This next bit is overkill for just trying to update the display -- it reloads the entire
        # MyAccount page!
        account.onLoad()
      .catch (error) ->
        account.setFlash('alert-success', "Some items could not be cancelled")
        $('#request-loading-spinner').spin(false)

  # Return a promise that cancels a single request
  cancelRequest: (netid, id) ->
    new Promise (resolve, reject) =>
      $.ajax({
        url: "/myaccount/ajax_cancel"
        type: "POST"
        data: { netid: netid, requestId: id }
        error: (jqXHR, textStatus, error) ->
          console.log("MyAccount error: Unable to cancel request #{id} (#{error})")
          account.updateItemStatus(id, { code: 400 })
          reject new Error("Sending an error 2")
        success: (result) ->
          # N.B. This operation succeeds if the CUL::FOLIO::Edge gem returns a response correctly.
          # That does not mean that *cancellation* has succeeded; for that, check the response code
          # in result
          if result.code < 300 
            account.removeEntry(id)
            resolve result
          else
            console.log("MyAccount error: Unable to cancel request #{id} (#{result.error})")
            reject result
      })

  # Using the item ID, show the status of a renewal operation in the appropriate table row.
  # result will be an object with an :error property and a :code (HTTP code) property.
  updateItemStatus: (id, result) ->
    message = if result.code < 300 then 'Renewed' else 'Renewal failed'
    $("##{id} td.status").html(message)

  # For a successufully cancelled request, remove the entry from the table
  removeEntry: (id) ->
    # Remove entry from the DOM
    $("##{id}").remove()
    # numRequests = requests.length
    # $('#pendingTab').html('Pending requests (' + numRequests + ')')
    # if numRequests < 1
    #   $('#pending-requests').html('<p>You have no pending requests.</p>')


  # The following approach and code for handling flash messages for AJAX calls are taken from
  # https://gist.github.com/hbrandl/5253211

  # ajax call to show flash messages when they are transmitted in the header
  # this code assumes the following
  #  1) you're using twitter-bootstrap 2.3 (although it will work if you don't)
  #  2) you've got a div with the id flash_hook somewhere in your html code
  ajaxComplete: (event, request) ->
    if request
      msg = request.getResponseHeader("X-Message")
      alert_type = 'alert-success'
      alert_type = 'alert-error' unless request.getResponseHeader("X-Message-Type").indexOf("error") is -1

      unless request.getResponseHeader("X-Message-Type").indexOf("keep") is 0
        account.setFlash(alert_type, msg)
  
  setFlash: (type, message) ->
    #add flash message if there is any text to display
    $("#main-flashes").replaceWith("<div id='flash_hook'>
        <p>&nbsp;</p>
            <div class='row'>
              <div class='span10 offset1'>
                <div class='alert " + type + "'>
                  <button type='button' class='close' data-dismiss='alert'>&times;</button>
                  " + message + "
                </div>
              </div>
            </div>
          </div>") if message
    #delete the flash message (if it was there before) when an ajax request returns no flash message
    $("#main-flashes").replaceWith("<div id='main-flashes'></div>") unless message