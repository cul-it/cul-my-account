module MyAccount
  class Voyager
    :attr_reader charged_items

    def initialize(netid)
      @charged_items = fetch_all_items netid
    end

    def fetch_all_items(netid)
      uri = URI.parse("https://voy-api.library.cornell.edu/cgi-bin/ilsapiE.cgi?netid=#{netid}")
      response = Net::HTTP.get_response(uri)
      record = JSON.parse(response.body)
      items = record['items']
      charged_items_array = []
      items.each do |i|
        # if options[:json]
        #   Rails.logger.debug "mjc12test:  #{i}" 
        # else
          Rails.logger.debug "mjc12test:  #{i['ou_title']}"  
          Rails.logger.debug "mjc12test:  #{i['ou_aulast']}" 
        # end
      end
    end
  end
end