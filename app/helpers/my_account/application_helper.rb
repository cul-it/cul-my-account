module MyAccount
  module ApplicationHelper

    # TODO: I'm not sure if we need any of the methods below!
    def method_missing method, *args, &block
      if method.to_s.end_with?('_path') || method.to_s.end_with?('_url')
        if main_app.respond_to?(method)
          main_app.send(method, *args)
        else
          super
        end
      else
        super
      end
    end

    def respond_to?(method,include_all=false)
      if method.to_s.end_with?('_path') || method.to_s.end_with?('_url')
        if main_app.respond_to?(method)
          true
        else
          super
        end
      else
        super
      end
    end

    def part_of_catalog?
      if params[:controller] =='catalog' || params[:controller]=='bookmarks' ||
        request.original_url.include?("request") || params[:controller]=='search_history' ||
        params[:controller] == 'advanced_search' || params[:controller]=='aeon' || params[:controller]=='browse' ||
        params[:controller] == 'book_bags'
        return true
      end
    end

    def render_solr_core
    
    end

  end
end
