(function() {
  var DATOM, SP, provide_extras;

  SP = require('steampipes');

  DATOM = require('datom');

  provide_extras = function() {
    //-----------------------------------------------------------------------------------------------------------
    this.$group_by = function(grouper) {
      /* TAINT, simplify, generalize, implement as standard transform `$group_by()` */
      var buffer, flush, last, prv_name, send;
      prv_name = null;
      buffer = null;
      send = null;
      last = Symbol('last');
      //.........................................................................................................
      flush = () => {
        if (!((buffer != null) && buffer.length > 0)) {
          return;
        }
        send(DATOM.new_datom('^group', {
          name: prv_name,
          value: buffer.slice(0)
        }));
        return buffer = null;
      };
      //.........................................................................................................
      return this.$({last}, (d, send_) => {
        var name;
        send = send_;
        if (d === last) {
          return flush();
        }
        //.......................................................................................................
        if ((name = grouper(d)) === prv_name) {
          return buffer.push(d);
        }
        //.......................................................................................................
        flush();
        prv_name = name;
        if (buffer == null) {
          buffer = [];
        }
        buffer.push(d);
        return null;
      });
    };
    //-----------------------------------------------------------------------------------------------------------
    this.$mark_position = function() {
      var is_first, last, prv;
      /* Turns values into objects `{ first, last, value, }` where `value` is the original value and `first`
         and `last` are booleans that indicate position of value in the stream. */
      // last      = @_symbols.last
      last = Symbol('last');
      is_first = true;
      prv = [];
      return this.$({last}, (d, send) => {
        if ((d === last) && prv.length > 0) {
          if (prv.length > 0) {
            send({
              is_first,
              is_last: true,
              d: prv.pop()
            });
          }
          return null;
        }
        if (prv.length > 0) {
          send({
            is_first,
            is_last: false,
            d: prv.pop()
          });
          is_first = false;
        }
        prv.push(d);
        return null;
      });
    };
    //-----------------------------------------------------------------------------------------------------------
    return this.mark_position = function(transform) {
      return this.pull(this.$mark_position(), transform);
    };
  };

  provide_extras.apply(SP);

  module.exports = SP;

}).call(this);

//# sourceMappingURL=steampipes-extra.js.map