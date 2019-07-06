(function() {
  'use strict';
  var $, $async, $watch, CND, H, PD, VNR, assign, badge, debug, declare, echo, first, help, info, isa, jr, last, rpr, select, size_of, stamp, type_of, types, urge, validate, warn, whisper;

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
  require('./exception-handler');

  first = Symbol('first');

  last = Symbol('last');

  VNR = require('./vnr');

  //...........................................................................................................
  PD = require('pipedreams');

  ({$, $watch, $async, select, stamp} = PD);

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, declare, size_of, type_of} = types);

  //-----------------------------------------------------------------------------------------------------------
  this.ignore_rows = function(S, first_lnr, last_lnr = null) {
    var dbw, first_vnr_blob, last_vnr_blob;
    dbw = S.mirage.dbw;
    first_vnr_blob = dbw.$.as_hollerith([first_lnr]);
    last_vnr_blob = dbw.$.as_hollerith([last_lnr]);
    if (last_lnr != null) {
      dbw.set_dest({
        first_vnr_blob,
        last_vnr_blob,
        dest: 'ignore'
      });
      dbw.set_ref({
        first_vnr_blob,
        last_vnr_blob,
        ref: 'stop'
      });
      dbw.stamp({first_vnr_blob, last_vnr_blob});
    } else {
      dbw.set_dest({
        first_vnr_blob,
        dest: 'ignore'
      });
      dbw.set_ref({
        first_vnr_blob,
        ref: 'stop'
      });
      dbw.stamp({first_vnr_blob});
    }
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this._get_lnr = function(row) {
    return (JSON.parse(row.vnr))[0];
  };

  //-----------------------------------------------------------------------------------------------------------
  this.mark_start = function(S) {
    var dbr, key, lnr, lnrs, pattern, row, rows, size;
    key = '^line';
    pattern = '<start/>';
    dbr = S.mirage.dbr;
    rows = dbr.$.all_rows(dbr.find_eq_pattern({key, pattern}));
    switch (size = size_of(rows)) {
      case 0:
        null;
        break;
      case 1:
        lnr = this._get_lnr(rows[0]);
        this.ignore_rows(S, 1, lnr);
        break;
      default:
        // info "µ33421 document start found on line #{lnr}"
        lnrs = ((function() {
          var i, len, results;
          results = [];
          for (i = 0, len = rows.length; i < len; i++) {
            row = rows[i];
            results.push(this._get_lnr(row));
          }
          return results;
        }).call(this)).join(', ');
        throw new Error(`µ22231 found ${size} ${pattern} tags, only up to one allowed (lines ${lnrs})`);
    }
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.mark_stop = function(S) {
    var dbr, key, lnr, lnrs, pattern, row, rows, size;
    key = '^line';
    pattern = '<stop/>';
    dbr = S.mirage.dbr;
    rows = dbr.$.all_rows(dbr.find_eq_pattern({key, pattern}));
    switch (size = size_of(rows)) {
      case 0:
        null;
        break;
      case 1:
        lnr = this._get_lnr(rows[0]);
        this.ignore_rows(S, lnr);
        break;
      default:
        // info "µ33421 document stop found on line #{lnr}"
        lnrs = ((function() {
          var i, len, results;
          results = [];
          for (i = 0, len = rows.length; i < len; i++) {
            row = rows[i];
            results.push(this._get_lnr(row));
          }
          return results;
        }).call(this)).join(', ');
        throw new Error(`µ22231 found ${size} ${pattern} tags, only up to one allowed (lines ${lnrs})`);
    }
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  /* NOTE pseudo-transforms that run before first datom is sent */
  this.$mark_start_and_stop = function(S) {
    return $watch({first}, (d) => {
      if (d !== first) {
        return null;
      }
      this.mark_start(S);
      this.mark_stop(S);
      return null;
    });
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$mark_start_and_stop(S));
    return PD.pull(...pipeline);
  };

}).call(this);
