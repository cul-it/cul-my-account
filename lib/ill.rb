module ILL
  require 'rest-client'
  
  def ill_transactions(user_id)
    transactions = fetch_ill_transactions(user_id)
    #transactions = filter_by_status(transactions)
    add_fields(transactions)
  end

  private

  # Fetches ILL (Interlibrary Loan) transactions for a given user via the ILLiad API.
  #
  # @param user_id [String] the ID of the user whose transactions are being fetched (netid or guest id)
  # @return [Array<Hash>] an array of objects representing the user's ILL transactions.
  # @raise [RestClient::ExceptionWithResponse] if the request to the ILLiad API fails.
  #
  # The method sends a GET request to the ILLiad API to retrieve the user's ILL transactions.
  # It expects the API key and URL to be set in the environment variables 'MY_ACCOUNT_ILLIAD_API_KEY' and 'MY_ACCOUNT_ILLIAD_API_URL'.
  def fetch_ill_transactions(user_id)
    headers = {
      'Accept' => 'application/json',
      'APIKey' => ENV['MY_ACCOUNT_ILLIAD_API_KEY']
    }
    response = RestClient.get "#{ENV['MY_ACCOUNT_ILLIAD_API_URL']}/Transaction/UserRequests/#{user_id}", headers
    transactions = JSON.parse(response.body)
    transactions
  end

  # Remove transactions that are completed or cancelled
  def filter_by_status(transactions)
    transactions.select do |transaction|
      !['Request Finished', 'Cancelled by ILL Staff', 'Cancelled by Customer'].include?(transaction['TransactionStatus'])
    end
  end

  # Add custom fields to each transaction. These are primarily used for display in the My Account requests views.
  # This method is a near-direct port of the illiad6.cgi Perl script that was previously used as a data source for ILLiad.
  # illiad6.cgi directly queried the ILLiad database, then added these fields to the results before passing
  # the whole thing back as a response. Why do we have ii, ou_genre, etc. as fields? Do we still need them
  # to be this obscure? Can we make them more readable? These are questions to ponder in the future.
  def add_fields(transactions)
    response = "{\"items\": [\n"
    items_array = []
    transactions.each do |transaction|
      tags_array = []

      genre = transaction['LoanTitle'] ? 'book' : 'article'
      title = transaction['LoanTitle'] || transaction['PhotoArticleTitle']
      title.gsub!(/"/, ' ')
      spot = title.index('/')
      title = title[0...spot - 1] if spot

      if genre == 'article'
        author_last_name = transaction['PhotoArticleAuthor']
        volume = transaction['PhotoJournalVolume']
        issn = transaction['ISSN']
        issue = transaction['PhotoJournalIssue']
        year = transaction['PhotoJournalYear']
        pages = transaction['PhotoJournalInclusivePages']
        full_title = "#{transaction['PhotoJournalTitle']} #{transaction['PhotoArticleTitle']} / #{transaction['PhotoArticleAuthor']} v.#{transaction['PhotoJournalVolume']} # #{transaction['PhotoJournalIssue']} pp. #{transaction['PhotoJournalInclusivePages']} #{transaction['PhotoJournalYear']}"
      else
        author_last_name = transaction['LoanAuthor']
        year = transaction['LoanDate']
        isbn = transaction['ISSN']
        spot = transaction['LoanTitle'].index('/')
        transaction['LoanTitle'] = transaction['LoanTitle'][0...spot - 1] if spot
        full_title = "#{transaction['LoanTitle']} / #{transaction['LoanAuthor']}"
      end

      #full_title.gsub!(/[\012\015]/, ' ').gsub!(/"/, ' ').gsub!(/"/, "'")
      location = transaction['NVTGC']
      due_date = transaction['DueDate']
      original_due_date = transaction['DueDate']
      renewals_allowed = transaction['RenewalsAllowed']
      date = due_date

      status = transaction['TransactionStatus']
      case status
      when 'Checked Out to Customer', 'Renewal Requested by Customer'
        status = "chrged"
        url = "https://cornell.hosts.atlas-sys.com/illiad/illiad.dll?Action=10&Form=66&Value=#{transaction['TransactionNumber']}"
      when 'Awaiting Verisign Payment'
        status = "waiting"
        url = "https://cornell.hosts.atlas-sys.com/illiad/illiad.dll?Action=10&Form=62"
      when 'Delivered to Web'
        status = "waiting"
        url = "https://cornell.hosts.atlas-sys.com/illiad/illiad.dll?Action=10&Form=75&Value=#{transaction['TransactionNumber']}"
      when 'Customer Notified via E-Mail'
        status = "waiting"
      else
        status = "pahr"
        url = "https://cornell.hosts.atlas-sys.com/illiad/illiad.dll?Action=10&Form=63&Value=#{transaction['TransactionNumber']}"
      end

      transaction_number = transaction['TransactionNumber']
      document_type = transaction['DocumentType']

      tags_array << "\"system\":\"illiad\""
      tags_array << "\"status\":\"#{status}\""
      tags_array << "\"ii\":\"#{transaction_number}\""
      tags_array << "\"it\":\"#{document_type}\""
      tags_array << "\"tl\":\"#{full_title}\""
      tags_array << "\"od\":\"#{original_due_date}\""
      tags_array << "\"rd\":\"#{due_date}\""
      tags_array << "\"lo\":\"#{location}\""
      tags_array << "\"ou_genre\":\"#{genre}\""
      tags_array << "\"ou_title\":\"#{title}\""
      tags_array << "\"ou_aulast\":\"#{author_last_name}\""
      tags_array << "\"ou_pages\":\"#{pages}\""
      tags_array << "\"ou_year\":\"#{year}\""
      tags_array << "\"ou_issue\":\"#{issue}\""
      tags_array << "\"ou_volume\":\"#{volume}\""
      tags_array << "\"ou_issn\":\"#{issn}\""
      tags_array << "\"url\":\"#{url}\""
    
      items_array << "{#{tags_array.join(",\n")}}"
    end

    response += items_array.join(",\n")
    response += "\n]\n}"
    response
  end

end