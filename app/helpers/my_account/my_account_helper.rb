module MyAccount
  module MyAccountHelper

    def isRenewable?(item)
      # Different sources use different indicators for this (why?)
      #  BD has 'AllowRenew'
      #  ILL has 'ra'
      #  Voyager has ?
      Rails.logger.debug "mjc12test: item #{item}"
      Rails.logger.debug "mjc12test: testing renew #1 #{item[:AllowRenew]}"
      Rails.logger.debug "mjc12test: testing renew #2 #{item[:ra]}"
      !((item['AllowRenew'] && item['AllowRenew'] == false) ||
        (item['ra'] && item['ra'] == 'No'))
    end

  end
end
