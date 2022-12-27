

@DATOM  = require 'datom'
@XE     = @DATOM.new_xemitter()
# await XE.emit '^mykey', 42
# await XE.emit { $key: '^mykey', $value: 42, }
