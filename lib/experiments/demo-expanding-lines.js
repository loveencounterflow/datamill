// Generated by CoffeeScript 2.4.1
(function() {
  'use strict';
  var $, $async, $watch, CND, DATAMILL, FS, MIRAGE, PATH, PD, assign, badge, debug, declare, do_validate, echo, first, format_object, help, info, isa, jr, last, rpr, select, size_of, stamp, type_of, types, urge, validate, warn, whisper;

  //###########################################################################################################
  CND = require('cnd');

  rpr = CND.rpr;

  badge = 'DATAMILL/EXPERIMENTS/EXPANDING-LINES';

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  info = CND.get_logger('info', badge);

  urge = CND.get_logger('urge', badge);

  help = CND.get_logger('help', badge);

  whisper = CND.get_logger('whisper', badge);

  echo = CND.echo.bind(CND);

  //...........................................................................................................
  FS = require('fs');

  PATH = require('path');

  PD = require('pipedreams');

  ({$, $watch, $async, select, stamp} = PD);

  ({assign, jr} = CND);

  first = Symbol('first');

  last = Symbol('last');

  types = require('../types');

  //...........................................................................................................
  ({isa, validate, declare, size_of, type_of} = types);

  //...........................................................................................................
  ({assign} = require('../helpers'));

  //...........................................................................................................
  require('../exception-handler');

  MIRAGE = require('mkts-mirage');

  do_validate = true;

  DATAMILL = require('../..');

  //-----------------------------------------------------------------------------------------------------------
  format_object = function(d) {
    var R, i, k, len, ref;
    R = {};
    ref = ((function() {
      var results;
      results = [];
      for (k in d) {
        results.push(k);
      }
      return results;
    })()).sort();
    for (i = 0, len = ref.length; i < len; i++) {
      k = ref[i];
      R[k] = d[k];
    }
    return jr(R);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.new_datom = function(...P) {
    var R;
    R = PD.thaw(PD.new_datom(...P));
    if (((!R.vnr_txt) != null) && (R.$vnr != null)) {
      R.vnr_txt = jr(R.$vnr);
    }
    R.$fresh = true;
    return PD.freeze(R);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.new_vnr_level = function(vnr, nr = 1) {
    var R;
    /* Given a `mirage` instance and a vectorial line number `vnr`, return a copy of `vnr`, call it
    `vnr0`, which has an index of `0` appended, thus representing the pre-first `vnr` for a level of lines
    derived from the one that the original `vnr` pointed to. */
    validate.nonempty_list(vnr);
    R = assign([], vnr);
    R.push(nr);
    return R;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.advance_vnr = function(vnr) {
    var R;
    /* Given a `mirage` instance and a vectorial line number `vnr`, return a copy of `vnr`, call it
    `vnr0`, which has its last index incremented by `1`, thus representing the vectorial line number of the
    next line in the same level that is derived from the same line as its predecessor. */
    validate.nonempty_list(vnr);
    R = assign([], vnr);
    R[vnr.length - 1] += +1;
    return R;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$split_words = function(S) {
    return $((d, send) => {
      var i, len, nxt_vnr, prv_vnr, ref, text, word;
      if (!select(d, '^mktscript')) {
        return send(d);
      }
      //.........................................................................................................
      send(stamp(d));
      text = d.value;
      prv_vnr = d.$vnr;
      nxt_vnr = this.new_vnr_level(prv_vnr);
      ref = text.split(/\s+/);
      //.........................................................................................................
      // unless isa.blank_text row.value
      for (i = 0, len = ref.length; i < len; i++) {
        word = ref[i];
        if (word === '') {
          continue;
        }
        nxt_vnr = this.advance_vnr(nxt_vnr);
        send(this.new_datom('^word', {
          text: word,
          $vnr: nxt_vnr
        }));
      }
      //.........................................................................................................
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$blank_lines = function(S) {
    var flush, linecount, prv_vnr, send, within_blank;
    prv_vnr = null;
    linecount = 0;
    send = null;
    within_blank = false;
    // is_first      = true
    //.........................................................................................................
    flush = (n) => {
      var $vnr;
      within_blank = false;
      $vnr = this.new_vnr_level(prv_vnr);
      send(PD.new_datom('^blank', {
        value: {linecount},
        $vnr,
        $fresh: true
      }));
      return linecount = 0;
    };
    //.........................................................................................................
    return $({last}, (d, send_) => {
      send = send_;
      //.......................................................................................................
      if (d === last) {
        flush(); // if within_blank
        return null;
      }
      if (!select(d, '^mktscript')) {
        //.......................................................................................................
        return send(d);
      }
      //.......................................................................................................
      if (!isa.blank_text(d.value)) {
        if (within_blank) {
          flush();
        }
        prv_vnr = d.$vnr;
        return send(d);
      }
      //.......................................................................................................
      send(stamp(d));
      prv_vnr = d.$vnr;
      if (!within_blank) {
        linecount = 0;
      }
      linecount += +1;
      within_blank = true;
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$headlines = function(S) {
    var pattern;
    pattern = /^\#+/;
    //.........................................................................................................
    return $((d, send) => {
      if (!select(d, '^mktscript')) {
        return send(d);
      }
      if ((d.value.match(pattern)) == null) {
        return send(d);
      }
      debug('µ33099', d);
      info('µ33099', this.previous_line_is_blank(S, d.$vnr));
      info('µ33099', this.next_line_is_blank(S, d.$vnr));
      return send(d);
    });
  };

  // info 'µ33344', row for row from S.mirage.db.followup { vnr: d.$vnr, }

  //-----------------------------------------------------------------------------------------------------------
  this.previous_line_is_blank = function(S, vnr) {
    var d;
    if ((d = this.get_previous_datom(S, vnr)) == null) {
      return true;
    }
    return (d.value.match(/^\s*$/)) != null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.next_line_is_blank = function(S, vnr) {
    var d;
    if ((d = this.get_next_datom(S, vnr)) == null) {
      return true;
    }
    return (d.value.match(/^\s*$/)) != null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.get_previous_datom = function(S, vnr) {
    var vnr_txt;
    /* TAINT consider to use types */
    if (vnr.length !== 1) {
      throw new Error(`µ33442 \`get_next_datom()\` not supported for nested vnrs, got ${rpr(vnr)}`);
    }
    if (!(vnr[0] > 1)) {
      /* TAINT need inverse to advance */
      return null;
    }
    vnr_txt = jr([vnr[0] - 1]);
    return this.datom_from_vnr(S, S, vnr);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.get_next_datom = function(S, vnr) {
    /* TAINT consider to use types */
    if (vnr.length !== 1) {
      throw new Error(`µ33442 \`get_next_datom()\` not supported for nested vnrs, got ${rpr(vnr)}`);
    }
    return this.datom_from_vnr(S, this.advance_vnr(vnr));
  };

  //-----------------------------------------------------------------------------------------------------------
  this.datom_from_vnr = function(S, vnr) {
    var dbr, row, sql, vnr_txt;
    sql = "select *\nfrom main\nwhere vnr_txt = $vnr_txt";
    vnr_txt = jr(vnr);
    dbr = S.mirage.db;
    if (!(row = dbr.$.first_row(dbr.$.query(sql, {vnr_txt})))) {
      return null;
    }
    return this.datom_from_row(S, row);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$phase_100 = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$blank_lines(S));
    return PD.pull(...pipeline);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$phase_200 = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$headlines(S));
    return PD.pull(...pipeline);
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.datom_from_row = function(S, row) {
    /* TAINT how to convert vnr in ICQL? */
    var $vnr, R, vnr_txt;
    vnr_txt = row.vnr_txt;
    $vnr = JSON.parse(vnr_txt);
    R = PD.new_datom(row.key, {
      value: row.value,
      $vnr
    });
    if (row.stamped) {
      R = PD.set(R, '$stamped', true);
    }
    return R;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.row_from_datom = function(S, d) {
    /* TAINT how to convert booleans in ICQL? */
    var R, stamped, value, vnr_txt;
    stamped = d.$stamped ? 1 : 0;
    vnr_txt = jr(d.$vnr);
    value = (isa.text(d.value)) ? d.value : jr(d.value);
    R = {
      key: d.key,
      vnr_txt,
      value,
      stamped
    };
    // MIRAGE.types.validate.mirage_main_row R if do_validate
    return R;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.feed_source = function(S, source, limit = 2e308) {
    var dbr, nr, ref, row;
    dbr = S.mirage.db;
    nr = 0;
    ref = dbr.read_unstamped_lines();
    //.........................................................................................................
    for (row of ref) {
      nr += +1;
      if (nr > limit) {
        break;
      }
      source.send(this.datom_from_row(S, row));
    }
    //.........................................................................................................
    source.end();
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$feed_db = function(S) {
    /* TAINT stopgap measure; should be implemented in ICQL */
    var db2;
    db2 = (MIRAGE.new_mirage(S.mirage)).db;
    return $watch((d) => {
      /* TAINT how to convert vnr in ICQL? */
      var error, row;
      row = this.row_from_datom(S, d);
      try {
        /* TAINT consider to use upsert instead https://www.sqlite.org/lang_UPSERT.html */
        if (d.$fresh) {
          db2.insert(row);
        } else if (d.$dirty) {
          db2.update(row);
        }
      } catch (error1) {
        error = error1;
        warn(`µ12133 when trying to insert or update row ${jr(row)}`);
        warn("µ12133 an error occurred:");
        warn(`µ12133 ${error.message}`);
        throw error;
      }
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this._$show = function(S) {
    return $watch((d) => {
      var color;
      if (d.$stamped) {
        color = CND.grey;
      } else {
        switch (d.key) {
          case '^word':
            color = CND.gold;
            break;
          default:
            color = CND.white;
        }
      }
      return info(color(jr(d)));
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.show_overview = function(S) {
    var color, dbr, key, ref, ref1, row, vnr;
    dbr = S.mirage.db;
    ref = dbr.read_lines({
      limit: 30
    });
    //.........................................................................................................
    for (row of ref) {
      // debug 'µ10001', rpr row
      if (row.stamped) {
        color = CND.grey;
      } else {
        color = (function() {
          switch (row.key) {
            case '^mktscript':
              return CND.red;
            case '^blank':
              return function(...P) {
                return CND.reverse(CND.grey(...P));
              };
            default:
              return CND.white;
          }
        })();
      }
      key = row.key.padEnd(12);
      vnr = row.vnr_txt.padEnd(12);
      info(color(`${vnr} ${(row.stamped ? 'S' : ' ')} ${key} ${rpr(row.value.slice(0, 41))}`));
    }
    ref1 = dbr.get_stats();
    //.........................................................................................................
    for (row of ref1) {
      info(`${row.key}: ${row.count}`);
    }
    //.........................................................................................................
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.run_phase = function(S, transform) {
    return new Promise((resolve, reject) => {
      var pipeline, source;
      source = PD.new_push_source();
      pipeline = [];
      pipeline.push(source);
      pipeline.push(transform);
      pipeline.push(this.$feed_db(S));
      pipeline.push(PD.$drain(() => {
        return resolve();
      }));
      PD.pull(...pipeline);
      return this.feed_source(S, source);
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.translate_document = function() {
    return new Promise(async(resolve, reject) => {
      var S, i, len, limit, mirage, phase, phases, transform;
      mirage = MIRAGE.new_mirage({
        source_path: './src/tests/demo.md',
        db_path: '/tmp/mirage.db'
      });
      await MIRAGE.acquire(mirage);
      S = {mirage};
      limit = 2e308;
      phases = ['$phase_100', '$phase_200'];
//.........................................................................................................
      for (i = 0, len = phases.length; i < len; i++) {
        phase = phases[i];
        transform = this[phase](S);
        help(`phase ${rpr(phase)}`);
        await this.run_phase(S, transform);
      }
      this.show_overview(S);
      resolve();
      //.........................................................................................................
      return null;
    });
  };

  //###########################################################################################################
  if (module.parent == null) {
    (async() => {
      await this.translate_document();
      return help('ok');
    })();
  }

}).call(this);

//# sourceMappingURL=demo-expanding-lines.js.map