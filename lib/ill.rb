# This module is an interface for ILLiad. Its primary function is to retrieve an array
# of ILL transactions for a given user, making use of the ILLiad API. The results are
# filtered and transformed into a JSON object that can be used by the My Account system.
module ILL
  require 'rest-client'
  
  def ill_transactions(user_id)
    transactions = fetch_ill_transactions(user_id)
    # NOTE: The following line should be redundant, but it's here for now, just in case. (See notes in fetch_ill_transactions)
    transactions = filter_by_status(transactions)
    transform_fields(transactions)
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
  # A filter is used in the query to try to only retrieve active transactions.
  def fetch_ill_transactions(user_id)
    headers = {
      'Accept' => 'application/json',
      'APIKey' => ENV['MY_ACCOUNT_ILLIAD_API_KEY']
    }
    # The filter is used here because I'm concerned about some users having massive numbers of old, completed transactions. I don't know if this
    # will speed up or slow down the query. In case this doesn't work properly, the filter_by_status method is called again after the query. The three
    # values used to catch completed transactions are the ones used in the old illid6.cgi script.
    filter = "not (TransactionStatus eq 'Request Finished' or TransactionStatus eq 'Cancelled by ILL Staff' or TransactionStatus eq 'Cancelled by Customer')"
    response = RestClient.get "#{ENV['MY_ACCOUNT_ILLIAD_API_URL']}/Transaction/UserRequests/#{user_id}?$filter=#{filter}", headers
    transactions = JSON.parse(response.body)
    transactions
  end

  # Remove transactions that are completed or cancelled
  def filter_by_status(transactions)
    transactions.select do |transaction|
      !['Request Finished', 'Cancelled by ILL Staff', 'Cancelled by Customer'].include?(transaction['TransactionStatus'])
    end
  end

  # Transform the transaction object. The replacement fields are primarily used for display in the My Account requests views.
  # This method is a near-direct port of the illiad6.cgi Perl script that was previously used as a data source for ILLiad.
  # illiad6.cgi directly queried the ILLiad database, then added these fields to the results before passing
  # the whole thing back as a response. Why do we have ii, ou_genre, etc. as fields? Do we still need them
  # to be this obscure? Can we make them more readable? These are questions to ponder in the future.
  def transform_fields(transactions)
    items_array = transactions.map do |transaction|
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
      # renewals_allowed = transaction['RenewalsAllowed']
      # date = due_date

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

      # TODO: Review these fields ... some of them are probably unnecessary.
      {
        system: "illiad",
        status: status,
        ii: transaction['TransactionNumber'],
        it: transaction['DocumentType'],
        tl: full_title,
        od: original_due_date,
        rd: due_date,
        lo: location,
        ou_genre: genre,
        ou_title: title,
        ou_aulast: author_last_name,
        # The following fields don't seem to be used anywhere.
        # ou_pages: pages,
        # ou_year: year,
        # ou_issue: issue,
        # ou_volume: volume,
        # ou_issn: issn,
        url: url,
        requestDate: transaction['CreationDate'],
        TransactionDate: transaction['TransactionDate'],
        TransactionNumber: transaction['TransactionNumber'],
        TransactionStatus: transaction['TransactionStatus']
      }
    end

    { items: items_array }.to_json
  end

end