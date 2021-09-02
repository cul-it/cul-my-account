$(document).ready ->
  account.onLoad()

account =
  requests: {
    folio: [],
    illiad: [],
    bd: [],
  }
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
          account.requests.folio = data.account.holds
          account.showCheckouts(data)
          account.showFines(data)
    })

    # Query the ILLiad CGI scripts to retrieve user's item requests
    illiadAccountLookup = $.ajax({
      url: "/myaccount/get_illiad_data"
      type: "POST"
      data: { netid }
      success: (data) ->
        account.requests.illiad = data
    })

    bdAccountLookup =$.ajax({
      url: "/myaccount/get_bd_requests"
      type: "POST"
      data: { netid }
      success: (data) ->
        newData = []
        for index, value of data
          newData.push(value)
        if newData.length > 0
          account.requests.bd = data
         # account.showRequests(account.requests.folio, account.requests.illiad, account.requests.bd)

    })

    # FOLIO account data is needed for both the checkouts pane and the requests panes. Requests in FOLIO
    # have to be combined with requests from ILLiad and BD, though, which takes a bit of manipulation.
    # So we use .when() here to do both lookups before proceeding
    # 
    # HACK: I don't really want to include Borrow Direct in this -- part of the motivation for using so 
    # much AJAX in this app was to keep the user from having to wait until the BD lookup is done, as that
    # can be excruciatingly slow at times. But if we don't wait for it here, then we run into concurrency
    # problems when populating the requests tabs and can get duplicate entries (for requests that are available
    # and thus are listed both in FOLIO as a charged item and in BD as an available request). It would be good
    # to figure out a better solution for this, but for now I'm including it here and forcing the whole thing
    # to wait till BD is ready.
    $.when(folioAccountLookup, illiadAccountLookup, bdAccountLookup).done (folioAccount, illiadAccount) ->
      if folioAccount[0].code > 200
        account.logError("couldn't retrieve user account data from FOLIO (#{folioAccount[0].error})")
        $("#checkouts").html("<span>Couldn't retrieve account information. Please ask a librarian for assistance.</span>")
      if illiadAccount[0] == undefined
        account.logError("couldn't retrieve user account data from ILLiad")

      account.showRequests(account.requests.folio, account.requests.illiad, account.requests.bd)
      .then () ->
        #account.setEvents()
    (error) ->
      account.logError("problem combining account lookup results (#{error})")

    # Enable tab navigation
    $('.nav-tabs a').click ->
      $(this).tab('show')
      account.setActionButtonState()

    account.userRecord = null
    # Look up user's name from FOLIO
    $.ajax({
      url: "/myaccount/get_user_record"
      type: "POST"
      data: { netid: netid }
      error: (jqXHR, textStatus, error) -> 
        account.logError("couldn't retrieve user record from FOLIO for #{netid} (#{error})")
      success: (data) ->
        account.userRecord = data.user
        nameSection = data.user.personal
        $('#userName').html("Account information for #{nameSection['firstName']} #{nameSection['lastName']}")
    })

  ######### END OF ONLOAD FUNCTION ###########

  # Enable or disable the action buttons for the current open tab
  # based on whether any items are selected in that tab
  setActionButtonState: () ->
    activeTab = $('.tab-pane.active').attr('id')
    buttonsDisabled = $('#' + activeTab + ' input:checkbox:checked').length < 1
    if (activeTab == 'checkouts')
      $('#renew').prop('disabled', buttonsDisabled)
    else if (activeTab == 'pending-requests')
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

    # Cancel button
    $('#cancel').click (e) ->
      e.preventDefault()
      e.stopPropagation()
      $('#request-loading-spinner').spin('cancelling')
      account.cancelItems()

  # Populate checkouts in the UI
  showCheckouts: (accountData) ->
    $.ajax({
      url: "/myaccount/ajax_checkouts"
      type: "POST"
      data: { checkouts: accountData.account.loans }
      error: (jqXHR, textStatus, error) ->
        account.logError("couldn't render checkouts template (#{error})")
      success: (data) ->
        $("#checkouts").html(data.record)
        $('#checkoutsTab').html('Checked out (' + data.locals.checkouts.length + ')')
        $('#renew').prop('disabled', true)
        # Enable/disable action buttons if any checkbox is selected
        $("input:checkbox").click ->
          account.setActionButtonState()
        # Set up renew button handler
        $('#renew').click (e) ->
          account.clearItemStatuses()
          $('#request-loading-spinner').spin('renewing')
          account.renewItems()
        # Add catalog links to the titles in the table
        data.locals.checkouts.forEach (checkout) ->
          account.addCatalogLink(checkout)

    })

  # Clear all the "status" values in the checkouts pane. This is used at the
  # beginning of a renew operation so that old statuses won't be confused
  # with new ones.
  clearItemStatuses: () ->
    $('td.status').html('')

  # Given an item ID, move that item down in the checkouts table
  # so that it's in its proper place based on a new due date after renewal.
  moveItemByDate: (id, newDueDate) ->
    rows = $('#checkouts-table tbody tr')
    return if rows.length < 2

    # Awkwardly newDueDate into a format we can use
    # Input format is e.g. "2022-07-30T03:59:59.000+0000"
    itemDueDate = new Date(newDueDate)
    formattedDueDate = "#{itemDueDate.getMonth() + 1}/#{itemDueDate.getDate()}/#{itemDueDate.getFullYear().toString().slice(2)}"

    # Get the index of the specified row
    oldIndex = 0
    rows.each (i, r) ->
      if r.id == id
        oldIndex = i
        # Update due date in the table row
        $(this).find('td.date').text(formattedDueDate)
      else
        # Is there a more efficient way of doing this? Probably, probably.
        currentRowDueDateTxt = $(this).find('td.date').text().trim()
        currentRowDueDate = new Date(currentRowDueDateTxt)
        if i == rows.length - 1
          # We've reached the last row, so just move the target row to the end
          $("##{id}").hide('slow', () ->
            $(this).insertAfter(rows[i]).show('slow')
          )
          return false
        else if currentRowDueDate > itemDueDate
          # Move the item to this new location
          $("##{id}").hide('slow', () ->
             $(this).insertBefore(rows[i]).show('slow')
          )
          return false


  # Given a checkout entry, call an ajax method to determine its instance bibid
  # and create a link to the catalog record, then add the link to the displayed title
  addCatalogLink: (entry) ->
    $.ajax({
      url: "/myaccount/ajax_catalog_link"
      type: "POST"
      data: { instanceId: entry.item.instanceId }
      error: (jqXHR, textStatus, error) ->
        account.logError("couldn't add catalog link for #{entry.id} (#{error})")
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
        account.logError("couldn't render fines template (#{error})")
      success: (data) ->
        fineTotal = '$' + accountData.account.totalCharges.amount
        $('#fines').html(data.record)
        $('#finesTab').html('Fines and fees (' + fineTotal + ')')
    })

  # Populate requests in the UI
  showRequests: (folioData, illiadData, bdData) ->
    # Combine ILLiad requests and FOLIO requests into the same arrays
    available = illiadData.available
    pending = illiadData.pending

    # Determining which requests should appear as pending or available, from three disparate data sources,
    # entails a number of awkward hacks. Here is the first one. If items from the ILL data feed have a
    # TransactionStatus of "Checked out in FOLIO", they should be filtered out of the array because they'll
    # be duplicated (with a more accurate status) in the FOLIO data
    pending = pending.filter (r) -> r.TransactionStatus != 'Checked out in FOLIO'

    # Sort out the FOLIO request data into the format and category expected by the views
    folioData.forEach (entry) ->
      # Look up the service point based on its ID. getServicePoint() will try to dynamically update the status
      # in the table when the result is ready
      account.getServicePoint(entry.pickupLocationId, entry.requestId)
      requestObj = {
        iid: entry.requestId, # N.B. The ID used here for FOLIO requests is the REQUEST ID, not the item ID!
        tl: entry.item.title,
        requestDate: entry.requestDate
      }
      # This is a weak way of determining available/pending status. Come up with something better?
      if entry.status.match(/^Open/) && !entry.status.match(/Awaiting pickup/)
        pending.push requestObj
      else
        available.push requestObj

    # Do the same sorting with the Borrow Direct data
    # BD entries look like this:
    # {
    #   au: <author>
    #   iid: COR-<number>
    #   status: <status>
    #   system: "bd"
    #   tl: <title>  
    # }
    # 
    # TODO: Handle other statuses once they're known
    pendingStatuses = ['ENTERED', 'IN_PROCESS', 'SHIPPED']
    availableStatuses = []
    bdData.forEach (entry) ->
      requestObj = {
        iid: entry.iid, # N.B. The ID used here for FOLIO requests is the REQUEST ID, not the item ID!
        tl: entry.tl,
        system: 'bd'
      }
      # This is a bit of a hack. An ON_LOAN item is really an available request, but at that point in
      # the process it shows up as a FOLIO loan item; if we include this one in available_requests,
      # we'll get a duplicate entry. So we'll ignore items with status ON_LOAN here.
      if entry.status != 'ON_LOAN'
        pending.push requestObj if pendingStatuses.includes(entry.status)
        available.push requestObj if availableStatuses.includes(entry.status)

    # Available requests tab
    $.ajax({
      url: "/myaccount/ajax_illiad_available"
      type: "POST"
      data: { requests: available }
      error: (jqXHR, textStatus, error) ->
        account.logError("couldn't render available requests template (#{error})")
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
        account.logError("couldn't render pending requests template (#{error})")
      success: (data) ->
        $("#pending-requests").html(data.record)
        $('#pendingTab').html('Pending requests (' + data.locals.pending_requests.length + ')')
        account.setActionButtonState()
        account.setEventHandlers()
    })

  getServicePoint: (id, requestId) ->
    $.ajax({
      url: "myaccount/ajax_service_point"
      type: "POST"
      data: { sp_id: id }
      error: (jqXHR, textStatus, error) ->
        account.logError("couldn't find service point #{sp_id} (#{error})")
      success: (data) ->
        $("##{requestId} td.location").html(data.service_point.discoveryDisplayName)
        return data.service_point
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
        if errors.length > 0
          reason = ''
          if errors.length == 1
            # If there's only one item being renewed, go ahead and show the error message
            # (this could be extended in future to show errors for multiple items, maybe,
            # but that might get confusing).
            reason = " (#{errors[0].error.errors[0].message})"
          if errors.length >= ids.length
            account.setFlash('alert-warning', "Renewal failed#{reason}")
          else
            account.setFlash('alert-warning', "Some items could not be renewed")
        else
          account.setFlash('alert-success', "Renewal succeeded")
        $('#request-loading-spinner').spin(false)
        window.scrollTo(0, 0)
      .catch (error) ->
        account.setFlash('alert-warning', "Some items could not be renewed")
        $('#request-loading-spinner').spin(false)

  # Return a promise that renews a single item
  renewItem: (netid, id) ->
    return new Promise (resolve, reject) =>
      $.ajax({
        url: "/myaccount/ajax_renew"
        type: "POST"
        data: { netid: netid, itemId: id }
        error: (jqXHR, textStatus, error) ->
          account.logError("unable to renew item #{id} (#{error})")
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
        account.setFlash('alert-warning', "Some items could not be cancelled")
        $('#request-loading-spinner').spin(false)

  # Return a promise that cancels a single request
  cancelRequest: (netid, id) ->
    new Promise (resolve, reject) =>
      $.ajax({
        url: "/myaccount/ajax_cancel"
        type: "POST"
        data: { netid: netid, requestId: id }
        error: (jqXHR, textStatus, error) ->
          account.logError("Unable to cancel request #{id} (#{error})")
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
            account.logError("Unable to cancel request #{id} (#{result.error})")
            reject result
      })

  # Using the item ID, show the status of a renewal operation in the appropriate table row.
  # result will be an object with an :error property and a :code (HTTP code) property.
  updateItemStatus: (id, result) ->
    if result.code < 300
      message = 'Renewed'
    else
      message = 'Renewal failed'
    $("##{id} td.status").html(message)
    if result.code < 300
      # Move the item down in the table to keep it sorted by due date
      account.moveItemByDate(id, result.due_date)

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
    # Add flash message if there is any text to display
    $("#main-flashes").replaceWith("<div id='main-flashes'>
      <div class='alert " + type + "'>
        <button type='button' class='close' data-dismiss='alert'>&times;</button>
        #{message}
      </div>
    ") if message
    #delete the flash message (if it was there before) when an ajax request returns no flash message
    $("#main-flashes").replaceWith("<div id='main-flashes'></div>") unless message

  logError: (message) ->
    console.log("MyAccount error: #{message}")