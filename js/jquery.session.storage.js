(function($){
  $.sessionStorage = new function() {

    var store = function(key, value) {
      sessionStorage.setItem(
        key, LZString.compressToUTF16(JSON.stringify(value))
      );
    };

    var retrieve = function(key) {
      return JSON.parse(LZString.decompressFromUTF16(
        sessionStorage.getItem(key)
      ));
    };

    var exists = function (key) {
      return (sessionStorage.getItem(key) != null)
    };

    var prefetch = function(key, source) {
      if (!exists(key)) {
        return source(key).then(function(data) {
          store(key, data);
          return data;
        });
      }
      return $.Deferred().resolve(retrieve(key)).promise();
    };

    this.prefetch = function(key, source) {
      return prefetch(key, source).then(function(data) {
        $(document).trigger("session:" + key + ":ready", data);
      });
    };

    this.pull = function(key, callback) {
      if (!exists(key)) {
        var event_type = "session:" + key + ":ready";
        $(document).on(event_type, function(event, data) {
          callback(data);
        });
      } else {
        callback(retrieve(key));
      }
    };
  };
})(jQuery);
