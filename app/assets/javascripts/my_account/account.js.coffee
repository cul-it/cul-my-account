$(document).ready ->
  account.onLoad()

account =
  onLoad: () ->
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
    # $('#renew').prop('disabled', true)
    # $('#export-checkouts').prop('disabled', true)
    account.setActionButtonState()

  # Enable or disable the action buttons for the current open tab
  # based on whether any items are selected in that tab
  setActionButtonState: (tab = null) ->
    console.log('entering set function; active tab is', $('.tab-pane.active').attr('id'))
    console.log('tab passed in', tab)
    activeTab = tab || $('.tab-pane.active').attr('id')
    # if a tab is passed in as a parameter, it's an href with an anchor (#) that we
    # don't want
    if (activeTab[0] == '#')
      activeTab = activeTab.substring(1)

    buttonsDisabled = $('#' + activeTab + ' input:checkbox:checked').length == 0
    console.log('buttons disabled', buttonsDisabled)

    if (activeTab == 'checkouts')
      $('#renew').prop('disabled', buttonsDisabled)
      $('#export-checkouts').prop('disabled', buttonsDisabled)
    else if (activeTab == 'available-requests')
      $('#export-available-requests').prop('disabled', buttonsDisabled)
    else if (activeTab == 'pending-requests')
      $('#cancel').prop('disabled', buttonsDisabled)
      $('#export-pending-requests').prop('disabled', buttonsDisabled)