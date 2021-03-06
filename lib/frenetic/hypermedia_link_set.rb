require 'delegate'
require 'active_support/core_ext/object/blank'

require 'frenetic/hypermedia_link'

class Frenetic
  class HypermediaLinkSet < Delegator
    def initialize( link_set = [] )
      link_set = [link_set] unless link_set.is_a? Array

      @link_set = link_set.map do |link|
        if link.is_a? HypermediaLink
          link
        else
          HypermediaLink.new link
        end
      end
    end

    def href( tmpl_vars = {} )
      return @link_set.first.href if tmpl_vars.blank?

      link = find_relevant_link( tmpl_vars ) and link.href( tmpl_vars )
    end

    def []( relation )
      @link_set.find{ |link| link.rel == relation.to_s }
    end

    def find_relevant_link( tmpl_vars )
      @link_set.find{ |link| link.expandable? tmpl_vars } or
        raise Frenetic::HypermediaError,
                "Could not find a relevant link for the data provided.\n" \
                "Are any of the links missing the templated:true property?\n" \
                "  Template Data: #{tmpl_vars}\n" \
                "  Link Set: #{@link_set.collect(&:as_json)}"
    end

    def __getobj__
      @link_set
    end
  end
end