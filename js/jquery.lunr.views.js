(function($) {
    
  var TemplateView = (function() {
    // Compile search results template
    var compile = function(template) {
      Mustache.parse(template);
      return function (view, partials) {
        return Mustache.render(template, view, partials);
      };
    };

    function TemplateView($support, options) {
      this.$support = $support;
      this.template = compile(options.template);
      this.doShow = options.doShow;
      this.doHide = options.doHide;
      this.doPreprocess = options.doPreprocess;
      this.toggleTime = options.toggleTime;
    };

    TemplateView.prototype.render = function(results, context) {
      if (this.doPreprocess) {
        results = this.doPreprocess(results, context);
      }
      this.$support.html(this.template($.extend({}, {
        entries: results, have_entries: (results.length != 0)
      }, context)));
      return $.Deferred().resolve();
    };

    TemplateView.prototype.show = function() {
      if (this.doShow) {
        return this.doShow(this.toggleTime);
      }
      this.$support.slideDown(this.toggleTime);
      return this.$support.promise();
    };

    TemplateView.prototype.hide = function() {
      if (this.doHide) {
        return this.doHide(this.toggleTime);
      }
      this.$support.slideUp(this.toggleTime);
      return this.$support.promise();
    };

    return TemplateView;
  })();

  $.fn.templateView = function(options) {
    options = $.extend({}, $.fn.templateView.defaults, options);
    return new TemplateView(this, options);
  };

  $.fn.templateView.defaults = {
    toggleTime: 400
  };

  var PagedView = (function() {
    function PagedView($support, options) {
      this.$support = $support;
      this.pageView = options.pageView;
      this.pageSize = options.pageSize;
      this.currentPage = options.initialPage;
      this.doShow = options.doShow;
      this.doHide = options.doHide;
      this.toggleTime = options.toggleTime;
    };

    PagedView.prototype.render = function(results, context) {
      var self = this;
      var deferred = $.Deferred();
      this.$support.pagination({
        dataSource: results,
        callback: function(partials) {
          self.pageView.render(partials, context);
        },
        afterPaging: function(page) {
          self.currentPage = page;
        },
        afterInit: function() {
          deferred.resolve();
        },
        ulClassName: "pagination pagination-sm",
        pageNumber: self.currentPage,
        pageSize: self.pageSize
      });
      return deferred.promise();
    };

    PagedView.prototype.show = function() {
      if (this.doShow) {
        return this.doShow(this.toggleTime);
      }
      var self = this;
      return $.when.apply($, [(function() {
        self.$support.slideDown(self.toggleTime);
        return self.$support.promise();
      })(), self.pageView.show(self.toggleTime)]);
    };

    PagedView.prototype.hide = function() {
      if (this.doHide) {
        return this.doHide(this.toggleTime);
      }
      var self = this;
      return $.when.apply($, [(function() {
        self.$support.slideUp(self.toggleTime);
        return self.$support.promise();
      })(), self.pageView.hide(self.toggleTime)]);
    };

    return PagedView;
  })();

  $.fn.pagedView = function(options) {
    options = $.extend({}, $.fn.pagedView.defaults, options);
    return new PagedView(this, options);
  };

  $.fn.pagedView.defaults = {
    toggleTime: 400
  };

})(jQuery);
