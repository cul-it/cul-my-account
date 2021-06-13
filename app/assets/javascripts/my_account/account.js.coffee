$(document).ready ->
  account.onLoad()

account =
  onLoad: () ->
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
    (error) ->
      console.log("MyAccount error in combining account lookup results (#{error})")

    # Enable tab navigation
    $('.nav-tabs a').click ->
      $(this).tab('show')
      account.setActionButtonState($(this).attr('href'))

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

  # Set up JS events after the content is loaded (see showCheckouts())
  setEvents: () ->
    # Select/deselect all checkboxes when clicked
    $('input:checkbox.select-all').click ->
      checked = $(this).prop('checked')
      $('tr.item input:checkbox').prop('checked', checked)

    # Enable/disable action buttons if any checkbox is selected
    $('input:checkbox').click ->
      account.setActionButtonState()

    # Disable action buttons
    account.setActionButtonState()

  # Enable or disable the action buttons for the current open tab
  # based on whether any items are selected in that tab
  setActionButtonState: (tab = null) ->
    activeTab = tab || $('.tab-pane.active').attr('id')
    # if a tab is passed in as a parameter, it's an href with an anchor (#) that we
    # don't want
    if (activeTab[0] == '#')
      activeTab = activeTab.substring(1)

    buttonsDisabled = $('#' + activeTab + ' input:checkbox:checked').length == 0

    if (activeTab == 'checkouts')
      $('#renew').click ->
        account.renewItems()
      $('#renew').prop('disabled', buttonsDisabled)
      $('#export-checkouts').prop('disabled', buttonsDisabled)
    else if (activeTab == 'pending-requests')
      $('#cancel').prop('disabled', buttonsDisabled)
      $('#cancel').click ->
        account.debounce(account.cancelItems(), 5000)

  debounce: (func, threshold, execAsap) ->
    timeout = null
    (args...) ->
      obj = this
      delayed = ->
        func.apply(obj, args) unless execAsap
        timeout = null
      if timeout
        clearTimeout(timeout)
      else if (execAsap)
        func.apply(obj, args)
      timeout = setTimeout delayed, threshold || 100

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
        account.setEvents()
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
        account.setEvents()
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
        account.setEvents()
    })

  renewItems: () ->
    netid = $('#accountData').data('netid')
    ids = []
    $('#checkouts input:checked').each () -> ids.push(this.id)

    # HACK - trim off the first array item if it doesn't contain an ID (it's the 'select all' checkbox)
    ids.shift() if ids[0] == ''

    ids.forEach (id) ->
      $.ajax({
        url: "/myaccount/ajax_renew"
        type: "POST"
        data: { netid: netid, itemId: id }
        error: (jqXHR, textStatus, error) ->
          console.log("MyAccount error: Unable to renew item #{id} (#{error})")
          account.updateItemStatus(id, { code: 400 })
        success: (result) ->
          # N.B. This operation succeeds if the CUL::FOLIO::Edge gem returns a response correctly.
          # That does not mean that *renewal* has succeeded; for that, check the response code
          # in result
          account.updateItemStatus(id, result)
      })

  cancelItems: () ->
    netid = $('#accountData').data('netid')
    ids = []
    $('#pending-requests input:checked').each () -> ids.push(this.id)

    # HACK - trim off the first array item if it doesn't contain an ID (it's the 'select all' checkbox)
    ids.shift() if ids[0] == ''

    ids.forEach (id) ->
      console.log("Canceling #{id}")
      $.ajax({
        url: "/myaccount/ajax_cancel"
        type: "POST"
        data: { netid: netid, requestId: id }
        error: (jqXHR, textStatus, error) ->
          console.log("MyAccount error: Unable to cancel request #{id} (#{error})")
          account.updateItemStatus(id, { code: 400 })
        success: (result) ->
          # N.B. This operation succeeds if the CUL::FOLIO::Edge gem returns a response correctly.
          # That does not mean that *cancellation* has succeeded; for that, check the response code
          # in result
          if result.code < 300 
            account.removeEntry(id)
          else
            console.log("MyAccount error: Unable to cancel request #{id} (#{result.error})")
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
