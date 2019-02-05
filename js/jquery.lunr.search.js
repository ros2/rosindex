(function($) {

  // prevent search from running too often
  var debouncedCall = function(fn) {
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

  var zipArray = function(x, y) {
    if (x.length > y.length) {
      var tmp = x; x = y; y = tmp;
    }
    return $.map(x, function(e, i) {
      return [[e, y[i]]];
    });
  };

  var unzipArray = function(z, fn) {
    return $.map(z, function(a) {
      return fn.apply(null, a);
    });
  };

  // define lunr.js search class
  var LunrSearch = (function() {

    function LunrSearch(input, options) {
      var self = this;

      this.$input = input;
      this.baseUrl = options.baseUrl;

      var views = $.map(options.sections, function(section) {
        return section.view;
      });
      $.when.apply($, $.map(options.sections, function(section) {
        return $.getLunrDB(section.partition, function(partition) {
          var query = self.$input.val();
          if (query) {
            var results = partition.search(query);
            if (results.length > 0) {
              return section.view.render(results, {
                baseurl: self.baseUrl
              });
            }
          }
        }).then(function(partition) {
          var query = self.$input.val();
          if (query) {
            var results = partition.search(query);
            return section.view.render(results, {
              baseurl: self.baseUrl
            }).then(function() {
              section.view.show();
              return partition;
            });
          }
          return section.view.hide().then(function() {
            return partition;
          });
        });
      })).then(function() {
        var sections = zipArray(views, arguments);
        self.$input.bind('search', function() {
          var query = self.$input.val();
          unzipArray(sections, function(view, partition) {
            if (query) {
              var results = partition.search(query);
              return view.render(results, {
                baseurl: self.baseUrl
              }).then(function() {
                view.show();
              });
            }
            return view.hide();
          });
        });
        self.bindInputKeys();
      }).then(function() {
        if (options.ready) {
          return options.ready();
        }
      });
    };

    // Bind keyup events to search results refreshes.
    LunrSearch.prototype.bindInputKeys = function() {
      var self = this;
      var oldValue = self.$input.val();
      self.$input.bind('keyup', debouncedCall(function() {
        var newValue = self.$input.val();
        if (newValue !== oldValue) {
          self.$input.trigger('search');
        }
        oldValue = newValue;
      }));
    };

    return LunrSearch;
  })();
 
  $.fn.lunrSearch = function(options) {
    // create search object
    options = $.extend({}, $.fn.lunrSearch.defaults, options);
    new LunrSearch(this, options);

    return this;
  };

  $.fn.lunrSearch.defaults = { baseUrl: '' };
})(jQuery);
