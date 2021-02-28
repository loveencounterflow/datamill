(function() {
  'use strict';
  var $, $async, $watch, CND, DATOM, H, SP, assign, badge, debug, declare, echo, first, freeze, help, info, isa, jr, last, new_datom, rpr, select, size_of, stamp, thaw, type_of, types, urge, validate, warn, whisper;

  //###########################################################################################################
  H = require('./helpers');

  CND = require('cnd');

  rpr = CND.rpr;

  badge = H.badge_from_filename(__filename);

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  info = CND.get_logger('info', badge);

  urge = CND.get_logger('urge', badge);

  help = CND.get_logger('help', badge);

  whisper = CND.get_logger('whisper', badge);

  echo = CND.echo.bind(CND);

  ({jr, assign} = CND);

  //...........................................................................................................
  first = Symbol('first');

  last = Symbol('last');

  //...........................................................................................................
  SP = require('steampipes');

  ({$, $watch, $async} = SP.export());

  //...........................................................................................................
  DATOM = require('datom');

  ({freeze, thaw, new_datom, select, stamp} = DATOM.export());

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, declare, size_of, type_of} = types);

  //-----------------------------------------------------------------------------------------------------------
  this.$ignore = function(S) {
    var within_ignore;
    within_ignore = false;
    return $((d, send) => {
      if (!select(d, '^line')) {
        return send(d);
      }
      if (d.text === '<ignore>') {
        within_ignore = true;
        return send(stamp(d, {
          dest: 'ignore',
          ref: 'ign'
        }));
      } else if (d.text === '</ignore>') {
        within_ignore = false;
        return send(stamp(d, {
          dest: 'ignore',
          ref: 'ign'
        }));
      } else if (within_ignore) {
        return send(stamp(d, {
          dest: 'ignore',
          ref: 'ign'
        }));
      } else {
        return send(d);
      }
    });
    return null;
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$ignore(S));
    return SP.pull(...pipeline);
  };

}).call(this);

//# sourceMappingURL=006-ignore.js.map