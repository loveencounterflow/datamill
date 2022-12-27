(function() {
  'use strict';
  //-----------------------------------------------------------------------------------------------------------
  this.DATOM = require('datom');

  this.XE = this.DATOM.new_xemitter();

  this.NOTIFIER = require('node-notifier');

  //-----------------------------------------------------------------------------------------------------------
  this._notify_change = function(path) {
    var settings;
    settings = {
      title: "File content changed",
      message: path,
      wait: false,
      timeout: 1
    };
    this.NOTIFIER.notify(settings);
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.XE.listen_to('^file-changed', (d) => {
    return this._notify_change(d.doc_file_path);
  });

}).call(this);

//# sourceMappingURL=_xemitter.js.map