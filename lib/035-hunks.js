(function() {
  'use strict';
  var $, $async, $watch, CND, H, PD, VNR, assign, badge, debug, declare, echo, first, help, info, isa, jr, last, last_of, rpr, select, size_of, stamp, type_of, types, urge, validate, warn, whisper;

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

  VNR = require('./vnr');

  //...........................................................................................................
  PD = require('steampipes');

  ({$, $watch, $async, select, stamp} = PD.export());

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, declare, size_of, last_of, type_of} = types);

  //...........................................................................................................

  //-----------------------------------------------------------------------------------------------------------
  this.$assemble_hunks = function(S) {
    var collect, collector, first_vnr, flush, prv_was_line, send;
    prv_was_line = false;
    send = null;
    first_vnr = null;
    collector = null;
    H.register_key(S, '^hunk', {
      is_block: false
    });
    //.........................................................................................................
    collect = function(d) {
      if (collector == null) {
        first_vnr = d.$vnr;
        collector = [];
      }
      collector.push(d);
      send(stamp(d));
      return null;
    };
    //.........................................................................................................
    flush = function() {
      var $vnr, text, x;
      if (collector == null) {
        return null;
      }
      text = ((function() {
        var i, len, results;
        results = [];
        for (i = 0, len = collector.length; i < len; i++) {
          x = collector[i];
          results.push(x.text);
        }
        return results;
      })()).join('\n');
      collector = null;
      $vnr = VNR.deepen(first_vnr);
      prv_was_line = false;
      send(H.fresh_datom('^hunk', {
        text,
        $vnr,
        ref: 'pco/asp'
      }));
      return null;
    };
    //.........................................................................................................
    return H.leapfrog_stamped($({last}, (d, send_) => {
      send = send_;
      //.......................................................................................................
      if (d === last) {
        return flush();
      }
      //.......................................................................................................
      if (!select(d, '^line')) {
        flush();
        return send(d);
      }
      //.......................................................................................................
      return collect(d);
    }));
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$assemble_hunks(S));
    return PD.pull(...pipeline);
  };

}).call(this);

//# sourceMappingURL=035-hunks.js.map