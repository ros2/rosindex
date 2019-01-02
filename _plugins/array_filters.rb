module Jekyll
  module ArrayFilters
    def include(input, which)
      input.include? which
    end
  end
end

Liquid::Template.register_filter(Jekyll::ArrayFilters)
