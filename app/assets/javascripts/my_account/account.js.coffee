$(document).ready ->
  account.onLoad()

account =
  onLoad: () ->
    # Main data loading section
    
    netid = $('#accountData').data('netid')

    # Query the FOLIO edge-patron API to retrieve user's checkouts and fines/fees.
    # The account object is passed along to separate handlers to process each
    # type of data individually.
    $.ajax({
      url: "/myaccount/get_folio_data"
      type: "POST"
      data: {netid: netid}
      error: (jqXHR, textStatus, error) ->
        console.log("MyAccount error: couldn't retrieve user account data from FOLIO for #{netid} (#{error})")
      success: (data) ->
        if data.code < 300
          account.showCheckouts(data)
          account.showFines(data)
        else
          console.log("MyAccount error: couldn't retrieve user account data from FOLIO for #{netid} (#{data.error})")

    })

    # Query the ILLiad CGI scripts to retrieve user's item requests
    $.ajax({
      url: "/myaccount/get_illiad_data"
      type: "POST"
      data: {netid: netid}
      error: (jqXHR, textStatus, error) ->
        console.log("MyAccount error: couldn't retrieve user account data from ILLiad for #{netid} (#{error})")
      success: (data) ->
        account.showRequests(data)
    })

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
    else if (activeTab == 'available-requests')
      $('#export-available-requests').prop('disabled', buttonsDisabled)
    else if (activeTab == 'pending-requests')
      $('#cancel').prop('disabled', buttonsDisabled)
      $('#export-pending-requests').prop('disabled', buttonsDisabled)

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
  showRequests: (requests) ->
    # Available requests tab
    $.ajax({
      url: "/myaccount/ajax_illiad_available"
      type: "POST"
      data: { requests: requests.available }
      error: (jqXHR, textStatus, error) ->
        console.log("MyAccount error: couldn't render available requests template (#{error})")
      success: (data) ->
        $('#available-requests').html(data.record)
        $('#availableTab').html('Ready for pickup (' + data.locals.available_requests.length + ')')
    })
    # Pending requests tab
    $.ajax({
      url: "/myaccount/ajax_illiad_pending"
      type: "POST"
      data: { requests: requests.pending }
      error: (jqXHR, textStatus, error) ->
        console.log("MyAccount error: couldn't render pending requests template (#{error})")
      success: (data) ->
        $("#pending-requests").html(data.record)
        $('#pendingTab').html('Pending requests (' + data.locals.pending_requests.length + ')')
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

  # Using the item ID, show the status of a renewal operation in the appropriate table row.
  # result will be an object with an :error property and a :code (HTTP code) property.
  updateItemStatus: (id, result) ->
    message = if result.code < 300 then 'Renewed' else 'Renewal failed'
    $("##{id} td.status").html(message)
    