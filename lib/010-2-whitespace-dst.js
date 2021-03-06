(function() {
  'use strict';
  var $, $async, $watch, CND, DATOM, DM, H, SPX, VNR, assign, badge, debug, declare, echo, first, freeze, help, info, is_stamped, isa, jr, last, new_datom, rpr, select, size_of, stamp, thaw, type_of, types, urge, validate, warn, whisper;

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

  DM = require('..');

  //...........................................................................................................
  SPX = require('./steampipes-extra');

  ({$, $watch, $async} = SPX.export());

  //...........................................................................................................
  DATOM = require('datom');

  ({VNR} = DATOM);

  ({freeze, thaw, new_datom, is_stamped, select, stamp} = DATOM.export());

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, declare, size_of, type_of} = types);

  //-----------------------------------------------------------------------------------------------------------
  this.$blanks_at_dest_changes = function(S) {
    return $({last}, (d_, send) => {
      var db;
      if (d_ !== last) {
        return send(d_);
      }
      db = S.mirage.dbw;
      (() => {        //.........................................................................................................
        var d, ref, ref1, results, row;
        ref = 'ws1/dst1';
        ref1 = db.read_changed_dest_last_lines();
        results = [];
        for (row of ref1) {
          if (select(row, '^blank')) {
            break;
          }
          d = H.datom_from_row(S, row);
          send(stamp(d));
          send(d = VNR.deepen(DATOM.set(d, {
            $fresh: true,
            ref
          })));
          results.push(send(H.fresh_datom('^blank', {
            linecount: 0,
            $vnr: VNR.advance(d.$vnr),
            dest: d.dest,
            ref
          })));
        }
        return results;
      })();
      (() => {        //.........................................................................................................
        var d, ref, ref1, results, row;
        ref = 'ws1/dst2';
        ref1 = db.read_changed_dest_first_lines();
        results = [];
        for (row of ref1) {
          if (select(row, '^blank')) {
            break;
          }
          d = H.datom_from_row(S, row);
          send(stamp(d));
          send(d = VNR.deepen(DATOM.set(d, {
            $fresh: true,
            ref
          })));
          results.push(send(H.fresh_datom('^blank', {
            linecount: 0,
            $vnr: VNR.recede(d.$vnr),
            dest: d.dest,
            ref
          })));
        }
        return results;
      })();
      return null;
    });
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$blanks_at_dest_changes(S));
    return SPX.pull(...pipeline);
  };

}).call(this);

//# sourceMappingURL=010-2-whitespace-dst.js.map