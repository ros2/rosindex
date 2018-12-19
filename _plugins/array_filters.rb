module Jekyll
  module ArrayFilters

    def drop(input, count)
      input.drop(count)
    end

    def keep(input, count)
      input[0, count]
    end

  end
end

Liquid::Template.register_filter(Jekyll::ArrayFilters)
