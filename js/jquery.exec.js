(function($) {

  function Executor(options) {
    var self = this;
    self.next = options.nextTag;
    self.loop_capacity = options.capacity;
    self.tagged_tasks = {};
    self.loop_count = 0;
  };

  Executor.prototype.pop = function() {
    var self = this;
    var tags = Object.keys(self.tagged_tasks);
    if (tags.length == 0) return null;
    var tag = self.next(tags);
    var task_list = self.tagged_tasks[tag];
    var task = task_list.shift();
    if (task_list.length == 0) {
      delete self.tagged_tasks[tag];
    }
    return task;
  };

  Executor.prototype.push = function(fn, tag) {
    var self = this;
    tag = tag || 'default';
    if (!(tag in self.tagged_tasks)) {
      self.tagged_tasks[tag] = [];
    }
    var future = $.Deferred();
    self.tagged_tasks[tag].push({
      action: fn, future: future
    });
    if (self.loop_count < self.loop_capacity) {
      self.loop_count += 1;
      self.spinAsync();
    }
    return future.promise();         
  };

  Executor.prototype.spinAsync = function() {
    var self = this;
    var task = self.pop();
    if (!task) {
      self.loop_count -= 1;
      return;
    }
    task.action().then(function(result) {
      task.future.resolve(result);
    }).then(function() {
      self.spinAsync();
    });
  };

  $.makeExecutor = function(options) {
    options = $.extend({}, $.makeExecutor.defaults, options);
    return new Executor(options);
  };

  $.makeExecutor.defaults = {
    nextTag: function(tags) {
      return tags[Math.floor(Math.random() * tags.length)];
    }, // Tag prioritization function.
    capacity: 2  // Maximum capacity for concurrent execution.
  };

})(jQuery);
