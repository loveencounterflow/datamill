(function() {
  this.DATOM = require('datom');

  this.XE = this.DATOM.new_xemitter();

  // await XE.emit '^mykey', 42
// await XE.emit { $key: '^mykey', $value: 42, }

}).call(this);

//# sourceMappingURL=_xemitter.js.map