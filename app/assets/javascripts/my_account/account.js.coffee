$(document).ready ->
  account.onLoad()

account =
  onLoad: () ->

    $('.nav-tabs a').click ->
      $(this).tab('show')
      
    $('input:checkbox.select-all').click ->
      checked = $(this).prop('checked')
      $('tr.item input:checkbox').prop('checked', checked)