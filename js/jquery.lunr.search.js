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

  var reduce = function(arr, fn, acum) {
    for (i = 0; i < arr.length; i += 1) {
      acum = fn(arr[i], acum);
    }
    return acum;
  };

  var partition = function(input, n) {
    output = [];
    for (i = 0; i < input.length; i += n) {
      output.push(input.slice(i, i + n));
    }
    return output;
  };

  // define lunr.js search class
  var LunrSearch = (function() {

    function LunrSearch(input, options) {
      var self = this;

      this.$input = input;
      this.$results = $(options.results);
      this.$pagination = $(options.pagination);
      this.page = null;

      this.template = this.compileTemplate($(options.template));
      this.templateVars = options.templateVars;

      this.indexLoaded = options.indexLoaded;
      this.invalidSearch = options.invalidSearch;
      this.validSearch = options.validSearch;

      var shards_promise = $.Deferred().resolve([{
          indexUrl: options.indexUrl,
          indexDataUrl: options.indexDataUrl
      }]);
      if (options.indexShardsUrl) {
        var urlParts = options.indexShardsUrl.split('/');
        var urlPrefix = urlParts.slice(0, urlParts.length - 1).join('/');
        shards_promise = $.getJSON(options.indexShardsUrl).then(function(shards) {
          return $.map(shards, function(shard) {
            return {indexUrl: urlPrefix + '/' + shard.index,
                    indexDataUrl: urlPrefix + '/' + shard.index_data};
          });
        });
      }

      this.shards = []
      shards_promise.then(function(shards) {
        var partitioning = partition(shards, options.maxConcurrentDownloads);
        reduce(partitioning, function(part, promise) {
          return promise.then(function() {
            return $.when.apply($, $.map(part, function(shard) {
              var promises = [];
              promises.push($.getJSON(shard.indexUrl).then(function(raw_index) {
                return lunr.Index.load(raw_index);
              }));
              promises.push($.getJSON(shard.indexDataUrl).then(function(raw_entries) {
                return raw_entries.reduce(function(hash, entry) {
                  hash[entry["id"]] = entry; return hash;
                }, {});
              }));
              return $.when.apply($, promises).then(function(index, entries) {
                self.shards.push({index: index, entries: entries});
              });
            })).then(function() {
              var query = self.$input.val();
              if (query) {
                var results = self.search(query);
                if (results.length > 0) {
                  return self.paginate(
                    results, self.page
                  ).then(self.validSearch);
                }
              }
            });
          });
        }, $.Deferred().resolve().promise()).then(function() {
          self.$input.bind('search', function() {
            var query = self.$input.val();
            if (query) {
              var results = self.search(query);
              self.paginate(
                results, self.page
              ).then(self.validSearch);
            } else {
              self.invalidSearch();
            }
          });

          self.bindInputKeys();
          self.indexLoaded();
        });
      });
      self.populateSearchFromQuery();
      $(window).bind('popstate', function() {
        self.populateSearchFromQuery();
        self.$input.trigger('search');
      });
      self.$input.bind('save', function() {
        if (self.$input.val()) {
          self.populateQueryFromSearch();
        }
      });
      self.bindSaveKeys();
    };

    // Compile search results template
    LunrSearch.prototype.compileTemplate = function($template) {
      var template = $template.text();
      Mustache.parse(template);
      return function (view, partials) {
        return Mustache.render(template, view, partials);
      };
    };

    // Bind keyup events to search results refreshes.
    LunrSearch.prototype.bindInputKeys = function() {
      var self = this;
      var oldValue = this.$input.val();
      this.$input.bind('keyup', debounce(function() {
        var newValue = self.$input.val();
        if (newValue !== oldValue) {
          self.$input.trigger('search');
        }
        oldValue = newValue;
      }));
    };

    LunrSearch.prototype.bindSaveKeys = function() {
      var self = this;
      this.$input.bind('keypress', debounce(function(e) {
        if (e.which == 13) {
          self.$input.trigger('save');
        }
      }));
    };

    LunrSearch.prototype.paginate = function(results, page) {
      var self = this;
      var deferred = $.Deferred();
      this.$pagination.pagination({
        dataSource: results,
        callback: function(entries, pagination) {
          var have_entries = (entries.length > 0);
          self.$results.html(
            self.template($.extend({}, {
              entries: entries,
              have_entries: have_entries,
            }, self.templateVars))
          );
        },
        afterPaging: function(page) {
          self.page = page;
        },
        afterInit: function() {
          deferred.resolve();
        },
        ulClassName: "pagination pagination-sm",
        pageNumber: page || 1,
        pageSize: 10
      });
      return deferred.promise();
    };

    // Search function that leverages lunr. If the query is too short
    // (i.e. less than 2 characters long), no search is performed.
    LunrSearch.prototype.search = function(query) {
      if (query.length < 2) {
        // Too short of a query, skip.
        return [];
      }
      // For each search result on each shard, grep all the entries
      // for the entry which corresponds to the result reference
      return $.map(this.shards, function (shard) {
        return $.map(shard.index.search(query), function(result) {
          return shard.entries[result.ref] || [];
        });
      });
    };

    // Populate the search input with 'q' querystring parameter if set
    LunrSearch.prototype.populateSearchFromQuery = function() {
      var uri = new URI(window.location.search.toString());
      var queryString = uri.search(true);

      if (queryString.hasOwnProperty('q')) {
        this.$input.val(queryString.q);
      } else {
        this.$input.val("");
      }
    };

    // Populate the search input with 'q' querystring parameter if set
    LunrSearch.prototype.populateQueryFromSearch = function() {
      var uri = new URI(window.location.toString());
      uri.setSearch({q: this.$input.val()});
      window.history.pushState({path: uri.toString()},
                                '', uri.toString());
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

  var deferred_noop = function() { return $.Deferred().resolve(); };
  $.fn.lunrSearch.defaults = {
    baseUrl: '',                 // Base url for search results links.
    indexUrl: '/index.json',     // Url for the .json file containing the
                                 // search index.
    indexDataUrl: '/search.json', // Url for the json file containing search
                                  // data.
    maxConcurrentDownloads: 2,    // Maximum concurrent downloads count allowed.
    pagination: '#search-pagination',  // Selector for pagination container
    results: '#search-results',  // Selector for results container
    template: '#search-results-template',  // Selector for Mustache.js template
    templateVars: {},
    invalidSearch: deferred_noop,
    validSearch: deferred_noop,
    indexLoaded: deferred_noop
  };
})(jQuery);
