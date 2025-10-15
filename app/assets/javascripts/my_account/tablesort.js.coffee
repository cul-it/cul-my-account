# Wait for the DOM to load
$(document).ready ->
  # Attach click event to <th> in any table with the class 'tablesort'
  # ... but skip any <th> that are marked nonsortable
  $(document).on 'click keydown', 'table.tablesort th', ->
    if event.type == 'keydown' and not (event.key == 'Enter' or event.key == ' ')
      return
    # stop the scrolling if its the 'Space' key
    event.preventDefault() if event.key == ' '

    header = $(this)
    headerText = header.text().trim()
    # skip <th> that are marked nonsortable
    if header.attr('data-nonsort')?
      return

    # Determine the sort direction
    table = header.closest('table')
    columnIndex = header.index()
    isAscending = header.hasClass('ascending')
    header.toggleClass('ascending', !isAscending)
    header.toggleClass('descending', isAscending)

    # Update aria-sort for the active <th> and reset others
    newSort = if isAscending then 'descending' else 'ascending'
    header.attr('aria-sort', newSort)
    header.siblings().attr('aria-sort', 'none')
    header.siblings().removeClass('ascending descending')
    $('#sort-announcement').text("#{header.text().trim()} sorted in #{newSort} order")
    sortTable(table, columnIndex, !isAscending, headerText)

  # Sort function...
  sortTable = (table, columnIndex, ascending, headerTitle) ->
    tbody = table.find('tbody')
    rows = tbody.find('tr').toArray()

    # Sort rows based on the content of the clicked column
    sortedRows = rows.sort (a, b) ->
      aText = $(a).children().eq(columnIndex).text().trim()
      bText = $(b).children().eq(columnIndex).text().trim()
      aTimestamp = $(a).children().eq(columnIndex).data('timestamp')
      bTimestamp = $(b).children().eq(columnIndex).data('timestamp')

      if aTimestamp? and bTimestamp?
        # Date sorting using timestamps
        if ascending then aTimestamp.localeCompare(bTimestamp) else bTimestamp.localeCompare(aTimestamp)
      else if !isNaN(aText) and !isNaN(bText)
        # Numeric sorting
        if ascending then aText - bText else bText - aText
      else
        # String sorting
        if ascending then aText.localeCompare(bText, undefined, { numeric: true }) else bText.localeCompare(aText, undefined, { numeric: true })

    # Append sorted rows back to the table
    tbody.append(sortedRows)
