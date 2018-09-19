(function($) {

  // prevent search from running too often
  var debounce = function(fn) {
    var timeout;
    var slice = Array.prototype.slice;

    return function() {
      var args = slice.call(arguments),
          ctx = this;

      clearTimeout(timeout);

      timeout = setTimeout(function () {
        fn.apply(ctx, args);
      }, 100);
    };
  };

  // define lunr.js search class
  var LunrSearch = (function() {

  function LunrSearch(input, options) {
      var self = this;

      this.$input = input;
      this.$results = $(options.results);
      this.$pagination = $(options.pagination);

      this.template = this.compileTemplate($(options.template));
      this.ready = options.ready;

      this.baseUrl = options.baseUrl;
      this.indexUrl = options.indexUrl;
      this.indexDataUrl = options.indexDataUrl;

      this.jxhr = [];

      this.jxhr.push($.getJSON(self.indexUrl, function(serialized_index) {
        console.log("loading " + self.indexUrl);
        self.index = lunr.Index.load(serialized_index);
      }));
      this.jxhr.push($.getJSON(self.indexDataUrl, function(index) {
        console.log("loading " + self.indexDataUrl);
        self.entries = index.entries;
      }));

      $.when.apply($, this.jxhr).done(function() {
          self.populateSearchFromQuery();
          self.resetSearchResults();
          self.bindKeypress();
          self.ready();
          console.log("done loading everything");
      });
    }

    // Compile search results template
    LunrSearch.prototype.compileTemplate = function($template) {
      var template = $template.text();
      Mustache.parse(template);
      return function (view, partials) {
        return Mustache.render(template, view, partials);
      };
    };

    // Bind keyup events to search results refreshes.
    LunrSearch.prototype.bindKeypress = function() {
      var self = this;

      var oldValue = self.$input.val();
      self.$input.bind('keyup', debounce(function() {
        var newValue = self.$input.val();
        if (newValue !== oldValue) {
          self.resetSearchResults();
        }
        oldValue = newValue;
      }));
    };

    LunrSearch.prototype.resetSearchResults = function() {
        var self = this;
        self.$pagination.pagination({
            dataSource: function(done) {
                done(self.search(self.$input.val()));
            },
            callback: function(entries, pagination) {
                var have_entries = (entries.length > 0);
                self.$results.html(
                    self.template({
                        entries: entries,
                        have_entries: have_entries,
                        baseurl: self.baseUrl
                    })
                );
            },
            ulClassName: "pagination pagination-sm",
            pageSize: 10
        });
    };

    // Search function that leverages lunr. If the query is too short
    // (i.e. less than 2 characters long), no search is performed.
    LunrSearch.prototype.search = function(query) {
      var self = this;
      if (query.length < 2) {
        // Too short of a query, skip.
        return [];
      }
      // For each search result, grep all the entries for the entry
      // which corresponds to the result reference
      return $.map(this.index.search(query), function(result) {
          return $.grep(self.entries, function(entry) {
              return entry.id === parseInt(result.ref, 10);
          })[0];
      });
    };

    // Populate the search input with 'q' querystring parameter if set
    LunrSearch.prototype.populateSearchFromQuery = function() {
      var uri = new URI(window.location.search.toString());
      var queryString = uri.search(true);

      if (queryString.hasOwnProperty('q')) {
        this.$input.val(queryString.q);
      }
    };

    return LunrSearch;
  })();

  $.fn.lunrSearch = function(options) {
    // apply default options
    options = $.extend({}, $.fn.lunrSearch.defaults, options);

    // create search object
    new LunrSearch(this, options);

    return this;
  };

  $.fn.lunrSearch.defaults = {
    baseUrl: '',                 // Base url for search results links.
    indexUrl: '/index.json',     // Url for the .json file containing the
                                 // search index.
    indexDataUrl: '/search.json', // Url for the json file containing search
                                  // data.
    pagination: '#search-pagination',  // Selector for pagination container
    results: '#search-results',  // Selector for results container
    template: '#search-results-template'  // Selector for Mustache.js template
  };
})(jQuery);
