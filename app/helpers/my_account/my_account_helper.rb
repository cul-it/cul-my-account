module MyAccount
  module MyAccountHelper

    # Return a properly title-cased title link based on whichever title field 
    # is populated in the record. If a catalog record exists (based on bib id)
    # then return a link; otherwise return a plain string.
    def cased_title_link item
      Rails.logger.debug "mjc12test: helping item #{item}"
      display_title = item['ou_title'].present? ? item['ou_title'].titleize : item['tl'].titleize
      # HACK: There is nothing in the retrieved record that explicitly states whether
      # a catalog record exists for it or not. (Once Borrow Direct -- and maybe ILL 
      # items are charged to a patron, they become temporary Voyager records almost
      # indistinguishable from regular records.) The one property that seems to offer
      # guidance is the 'lo' (location) field, which is unpopulated for BD/ILL records
      # but indicates an actual library location for Voyager records.
      item['lo'] == '' ?
        display_title :
        link_to(display_title, "https://newcatalog.library.cornell.edu/catalog/#{item['bid']}") 
    end

  end
end
