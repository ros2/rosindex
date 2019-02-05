(function($) {

  var LunrDB = (function() {
    function LunrDB() {
      this.shards = [];
    };

    // Search function that leverages lunr. If the query is too short
    // (i.e. less than 2 characters long), no search is performed.
    LunrDB.prototype.search = function(query) {
      try {
        if (query.length < 2) {
          // Too short of a query, skip.
          return [];
        }
        // For each search result on each shard, grep all the entries
        // for the entry which corresponds to the result reference
        return $.map(this.shards, function (shard) {
          return $.map(shard.index.search(query), function(result) {
            return $.extend({}, shard.data[result.ref] || {}, {
              _metadata: Object.values(result.matchData.metadata)[0]
            });
          });
        });
      } catch (err) {
        console.log(err.message);
        return [];
      }
    };

    LunrDB.prototype.extend = function(data) {
      this.shards.push(data);
    };

    return LunrDB;
  })();
  
  var getLunrDB = function(options, progress) {
    var shards_promise = $.Deferred().resolve([{
      indexUrl: options.indexUrl,
      dataUrl: options.dataUrl
    }]);

    if (options.shardsUrl) {
      var urlParts = options.shardsUrl.split('/');
      var urlPrefix = urlParts.slice(0, urlParts.length - 1).join('/');
      shards_promise = options.getData(options.shardsUrl).then(function(shards) {
        return $.map(shards, function(shard) {
          return {indexUrl: urlPrefix + '/' + shard.index,
                  dataUrl: urlPrefix + '/' + shard.data};
        });
      });
    }
    var db = new LunrDB();
    return shards_promise.then(function(shards) {
      return $.when.apply($, $.map(shards, function(shard) {
        var promises = [];
        promises.push(options.getData(shard.indexUrl).then(function(raw_index) {
          return lunr.Index.load(raw_index);
        }));
        promises.push(options.getData(shard.dataUrl).then(function(raw_data) {
          return raw_data.reduce(function(hash, entry) {
            hash[entry["id"]] = entry;
            return hash;
          }, {});
        }));
        return $.when.apply($, promises).then(function(index, data) {
          db.extend({index: index, data: data});
        });
      })).then(function() {
        return progress(db);
      });
    }).then(function() {
      if (options.ready) {
        options.ready();
      }
      return db;
    });
  };

  $.getLunrDB = function(options, progress) {
    options = $.extend({}, $.getLunrDB.defaults, options);
    return getLunrDB(options, progress);
  };

  $.getLunrDB.defaults = {
    indexUrl: '/index.json',  // Url for the .json file containing the search index.
    dataUrl: '/search.json'  // Url for the .json file containing search data.
  };
})(jQuery);
