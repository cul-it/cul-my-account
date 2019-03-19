$(document).ready ->
  account.onLoad()

account =
  onLoad: () ->

    $('.nav-tabs a').click ->
      $(this).tab('show')
      
    $('input:checkbox.select-all').click ->
      checked = $(this).prop('checked')
      $('tr.item input:checkbox').prop('checked', checked)

    # $('#renew').click ->
    #   ids = []
    #   items = $('input:checked').each (index, element) =>
    #     ids.push $(element).closest('tr').attr('id')
    #   $(ids).each (index, id) ->
    #     url = "https://catalog.library.cornell.edu/vxws/patron/138789/circulationActions/loans/1@CORNELLDB20021226150546|#{id}?patron_homedb=1@CORNELLDB20021226150546"
    #     console.log("renewing ", id, url)
    #     renew_request = $.post url
    #     renew_request.success (data) ->
    #       console.log("SUCCESS", data)
    #     renew_request.error (jqXHR, textStatus, errorThrown) ->
    #       console.log("ERROR", textStatus, errorThrown)
