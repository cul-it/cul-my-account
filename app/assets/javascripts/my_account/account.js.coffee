$(document).ready ->
  account.onLoad()

account =
  onLoad: () ->
    $('.nav-tabs a').click ->
      $(this).tab('show')
    $('#select-all-checkbox').click ->
      checked = $(this).prop('checked')
      $('tr.item input:checkbox').prop('checked', checked)