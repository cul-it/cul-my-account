module MyAccount
  module MyAccountHelper

    def isRenewable?(item)
      # Different sources use different indicators for this (why?)
      #  BD has 'AllowRenew'
      #  ILL has 'ra'
      #  Voyager has ?
      !((item['AllowRenew'] && item['AllowRenew'] == false) ||
        (item['ra'] && item['ra'] == 'No'))
    end

  end
end
