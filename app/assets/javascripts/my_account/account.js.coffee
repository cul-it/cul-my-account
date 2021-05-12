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
      error: (jqXHR, textStatus, errorThrown) ->
        console.log("got error")
      success: (data, textStatus, jqXHR) ->
        account.showCheckouts(data)
        account.showFines(data)
    })

    # Query the ILLiad CGI scripts to retrieve user's item requests
    $.ajax({
      url: "/myaccount/get_illiad_data"
      type: "POST"
      data: {netid: netid}
      error: (jqXHR, textStatus, errorThrown) ->
        console.log("got error")
      success: (data, textStatus, jqXHR) ->
        account.showRequests(data)
    })

    # Enable tab navigation
    $('.nav-tabs a').click ->
      $(this).tab('show')
      account.setActionButtonState($(this).attr('href'))
      
    # Select/deselect all checkboxes when clicked
    $('input:checkbox.select-all').click ->
      checked = $(this).prop('checked')
      $('tr.item input:checkbox').prop('checked', checked)

    # Enable/disable action buttons if any checkbox is selected
    $('input:checkbox').click ->
      account.setActionButtonState()

    # Disable action buttons on intial page load
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
      # dataType: "json"
      error: (jqXHR, textStatus, errorThrown) ->
        console.log("got error 2", errorThrown)
      success: (data, textStatus, jqXHR) ->
        $("#checkouts").html(data.record)
        $('#checkoutsTab').html('Checked out (' + data.locals.checkouts.length + ')')
    })

  # Populate fines/fees in the UI
  showFines: (accountData) ->
    console.log("passing through fines", accountData)

    $.ajax({
      url: "/myaccount/ajax_fines"
      type: "POST"
      data: { fines: accountData.account.charges }
      # dataType: "json"
      error: (jqXHR, textStatus, errorThrown) ->
        console.log("got error 2", errorThrown)
      success: (data, textStatus, jqXHR) ->
        fineTotal = '$' + accountData.account.totalCharges.amount
        $("#fines").html(data.record)
        $('#finesTab').html('Fines and fees (' + fineTotal + ')')
    })

  # Populate requests in the UI
  showRequests: (requests) ->
    console.log("passing through requests", requests)
    $.ajax({
      url: "/myaccount/ajax_illiad_available"
      type: "POST"
      data: { requests: requests.pending }
      # dataType: "json"
      error: (jqXHR, textStatus, errorThrown) ->
        console.log("got error 2", errorThrown)
      success: (data, textStatus, jqXHR) ->
        console.log("success", data)
        $("#available-requests").html(data.record)

        # fineTotal = '$' + accountData.account.totalCharges.amount
        # $("#fines").html(data.record)
        # $('#finesTab').html('Fines and fees (' + fineTotal + ')')
    })
    $.ajax({
      url: "/myaccount/ajax_illiad_pending"
      type: "POST"
      data: { requests: requests.pending }
      # dataType: "json"
      error: (jqXHR, textStatus, errorThrown) ->
        console.log("got error 2", errorThrown)
      success: (data, textStatus, jqXHR) ->
        console.log("success p", data)

        $("#pending-requests").html(data.record)

        # console.log("fine result", accountData)
        # fineTotal = '$' + accountData.account.totalCharges.amount
        # $("#fines").html(data.record)
        # $('#finesTab').html('Fines and fees (' + fineTotal + ')')
    })