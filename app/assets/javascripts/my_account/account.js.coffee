$(document).ready ->
  account.onLoad()

account =
  onLoad: () ->
    # EXPERIMENTS
    $.ajax({
      url: "/myaccount/ajax"
      type: "GET"
      error: (jqXHR, textStatus, errorThrown) ->
        console.log("got error")
      success: (data, textStatus, jqXHR) ->
        console.log("success!", data)
    })
    netid = $('#accountData').data('netid')

    $.ajax({
      url: "/myaccount/get_patron_stuff"
      type: "POST"
      data: {netid: netid}
      # dataType: "json"
      error: (jqXHR, textStatus, errorThrown) ->
        console.log("got error 2", errorThrown)
      success: (data, textStatus, jqXHR) ->
        $("#checkouts").html(data.record)
        $('#checkoutsTab').html('Checked out (' + data.locals.checkouts.length + ')')
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