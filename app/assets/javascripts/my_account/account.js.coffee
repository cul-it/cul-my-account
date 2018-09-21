$(document).ready ->
  account.onLoad()

account =
  onLoad: () ->
    $('.nav-tabs a').click ->
      console.log("boom")
      $(this).tab('show')