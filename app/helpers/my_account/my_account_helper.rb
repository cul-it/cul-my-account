module MyAccount
  module MyAccountHelper

    # Return a properly title-cased title link based on whichever title field 
    # is populated in the record. If a catalog record exists (based on bib id)
    # then return a link; otherwise return a plain string.
    def cased_title_link item
      item['item']['title'].titleize
      # HACK: There is nothing in the retrieved record that explicitly states whether
      # a catalog record exists for it or not. (Once BorrowDirect -- and maybe ILL 
      # items are charged to a patron, they become temporary Voyager records almost
      # indistinguishable from regular records.) The one property that seems to offer
      # guidance is the 'lo' (location) field, which is unpopulated for BD/ILL records
      # but indicates an actual library location for Voyager records.
      # item['lo'] == '' || item['TransactionNumber'] ?
      #   display_title :
      #   link_to(display_title, "https://newcatalog.library.cornell.edu/catalog/#{item['bid']}") 
    end

    # Return a user-readable item status message. This will filter out the 'pahr' statuses that turn
    # up from time to time but are inscrutable to users.
    # def status_display item
    #   status = item['vstatus'] || item['status']
    #   return "" if status.nil? 
    #   status == 'pahr' ? '' : status.gsub("Charged","Checked Out").gsub("Recall Request Checked Out", "Recall Request, Checked Out").gsub("/Withdrawn","")
    # end

    # Repurposed from previous method to display "overdue" where appropriate, or renewal status after an attempt to renew
    def status_display item
      return "Overdue" if item['overdue'] == 'true'
    end

    # Return a 'system' data tag for a checkout. Can be FOLIO or Illiad for now. Note that
    # this is *not* the same as the 'system' field in the item metadata. Instead, this goes on the assumption that
    # a TransactionNumber indicates an Illiad loan.
    def system_tag item
      item['TransactionNumber'].present? ? 'illiad' : 'folio'
    end
  end
end
