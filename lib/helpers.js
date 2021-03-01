(function() {
  'use strict';
  var $, $async, $watch, CND, DATOM, DM, PATH, SP, XXX_COLORIZER, _color_cache, assign, badge, cast, debug, declare, echo, equals, freeze, fresh_datom, help, info, is_stamped, isa, jr, new_datom, rpr, select, size_of, stamp, thaw, to_width, type_of, types, urge, validate, warn, whisper, width_of;

  //###########################################################################################################
  CND = require('cnd');

  rpr = CND.rpr;

  badge = 'DATAMILL/HELPERS';

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  info = CND.get_logger('info', badge);

  urge = CND.get_logger('urge', badge);

  help = CND.get_logger('help', badge);

  whisper = CND.get_logger('whisper', badge);

  echo = CND.echo.bind(CND);

  ({jr, assign} = CND);

  //...........................................................................................................
  PATH = require('path');

  ({to_width, width_of} = require('to-width'));

  //...........................................................................................................
  SP = require('steampipes');

  ({$, $watch, $async} = SP.export());

  //...........................................................................................................
  DATOM = require('datom');

  ({freeze, thaw, new_datom, fresh_datom, is_stamped, select, stamp} = DATOM.export());

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, cast, declare, equals, size_of, type_of} = types);

  XXX_COLORIZER = require('./experiments/colorizer');

  DM = require('..');

  // debug '^555566^', ( k for k of DATOM.VNR ); process.exit 55

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.cwd_abspath = CND.cwd_abspath;

  this.cwd_relpath = CND.cwd_relpath;

  this.here_abspath = CND.here_abspath;

  this._drop_extension = (path) => {
    return path.slice(0, path.length - (PATH.extname(path)).length);
  };

  this.project_abspath = (...P) => {
    return CND.here_abspath(__dirname, '..', ...P);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.badge_from_filename = function(filename) {
    var basename;
    basename = PATH.basename(filename);
    return 'DATAMILL/' + (basename.replace(/^(.*?)\.[^.]+$/, '$1')).toUpperCase();
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.format_object = (d) => {
    var R, i, k, len, ref1;
    R = {};
    ref1 = ((function() {
      var results;
      results = [];
      for (k in d) {
        results.push(k);
      }
      return results;
    })()).sort();
    for (i = 0, len = ref1.length; i < len; i++) {
      k = ref1[i];
      R[k] = d[k];
    }
    return jr(R);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.new_datom = (...P) => {
    return new_datom(...P);
  };

  this.fresh_datom = (...P) => {
    return fresh_datom(...P);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.swap_key = function(d, key, $vnr = null) {
    var R;
    /* Given a datom `d`, compute the first `$vnr` for the next level (or use the optional `$vnr` argument)
     and set the `key` on a copy. Make sure `$fresh` is set and `$dirty` is unset.
     */
    if ($vnr == null) {
      $vnr = VNR.new_level(d.$vnr, 1);
    }
    R = d;
    R = SP.set(R, '$key', key);
    R = SP.set(R, '$vnr', $vnr);
    R = SP.set(R, '$fresh', true);
    R = SP.unset(R, '$dirty');
    return R;
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.leapfrog_stamped = function(transform) {
    debug('^222332^', transform);
    debug('^222332^', type_of(transform));
    return SP.leapfrog((function(d) {
      return is_stamped(d);
    }), transform);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$filter_stamped = function() {
    return SP.$filter(function(d) {
      return !is_stamped(d);
    });
  };

  //===========================================================================================================
  // DB QUERIES
  //-----------------------------------------------------------------------------------------------------------
  this.row_from_vnr = (S, vnr) => {
    var dbr;
    validate.vnr(vnr);
    dbr = S.mirage.dbr;
    vnr = JSON.stringify(vnr);
    return dbr.$.first_row(dbr.datom_from_vnr({vnr}));
  };

  //-----------------------------------------------------------------------------------------------------------
  this.datom_from_vnr = (S, vnr) => {
    var row;
    if ((row = this.row_from_vnr(S, vnr)) == null) {
      return null;
    }
    return this.datom_from_row(S, row);
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.register_new_key = (S, key, settings) => {
    var db, error, has_paragraphs, is_block, ref1, ref2;
    validate.datamill_register_key_settings(settings);
    DATOM.types.validate.datom_key(key);
    db = S.mirage.dbw;
    is_block = cast('boolean', 'float', (ref1 = settings.is_block) != null ? ref1 : false);
    has_paragraphs = cast('boolean', 'float', (ref2 = settings.has_paragraphs) != null ? ref2 : false);
    try {
      db.register_key({key, is_block, has_paragraphs});
    } catch (error1) {
      error = error1;
      if (!error.message.startsWith("UNIQUE constraint failed")) {
        throw error;
      }
      // throw new Error "µ77754 key #{rpr key} already registered"
      warn(`µ77754 key ${rpr(key)} already registered`);
    }
    this._key_registry_cache = null;
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.register_key = (S, key, settings) => {
    var db, definition, entry, has_paragraphs, is_block, ref1, ref2, ref3, ref4;
    /* TAINT code duplication */
    validate.datamill_register_key_settings(settings);
    DATOM.types.validate.datom_key(key);
    db = S.mirage.dbw;
    is_block = (ref1 = settings.is_block) != null ? ref1 : false;
    has_paragraphs = (ref2 = settings.has_paragraphs) != null ? ref2 : false;
    if ((entry = db.$.first_row(db.get_key_entry({key}))) == null) {
      return this.register_new_key(S, key, settings);
    }
    definition = {key, is_block, has_paragraphs};
    entry.is_block = cast('float', 'boolean', (ref3 = entry.is_block) != null ? ref3 : 0);
    entry.has_paragraphs = cast('float', 'boolean', (ref4 = entry.has_paragraphs) != null ? ref4 : 0);
    if (!equals(definition, entry)) {
      throw new Error(`µ87332 given key definition ${jr(definition)} doesn't match esisting entry ${rpr(entry)}`);
    }
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this._key_registry_cache = null;

  //-----------------------------------------------------------------------------------------------------------
  this.get_key_registry = (S) => {
    var R, db, key, ref1, row;
    if (this._key_registry_cache != null) {
      return this._key_registry_cache;
    }
    db = S.mirage.dbw;
    R = {};
    ref1 = db.read_key_registry();
    for (row of ref1) {
      for (key in row) {
        row[key] = (function() {
          switch (row[key]) {
            case 1:
              return true;
            case 0:
              return false;
            default:
              return row[key];
          }
        })();
      }
      R[row.key] = row;
    }
    this._key_registry_cache = freeze(R);
    return R;
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.register_realm = (S, realm) => {
    S.mirage.dbw.register_realm({realm});
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.copy_realm = function(S, from_realm, to_realm, selector = null) {
    /* TAINT find a way to use fewer positional arguments */
    var dbw, select_row;
    validate.datamill_realm(from_realm);
    validate.datamill_realm(to_realm);
    if (selector != null) {
      validate.function(selector);
    }
    dbw = S.mirage.dbw;
    //.........................................................................................................
    if (selector != null) {
      select_row = (rowid, vnr, dest, sid, realm, ref, key, text, p) => {
        var d, row;
        row = {vnr, dest, sid, realm, ref, key, text, p};
        d = this.datom_from_row(S, row);
        return cast('boolean', 'float', selector(d));
      };
    } else {
      //.........................................................................................................
      select_row = (rowid, vnr, dest, sid, realm, ref, key, text, p) => {
        return 1;
      };
    }
    //.........................................................................................................
    dbw.$.function('datamill_copy_realm_select', {
      deterministic: false,
      varargs: false
    }, select_row);
    dbw.copy_realms({from_realm, to_realm});
    return null;
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.datom_from_row = (S, row) => {
    var $vnr, R, k, p, ref1, vnr;
    vnr = row.vnr;
    $vnr = JSON.parse(vnr);
    p = row.p != null ? JSON.parse(row.p) : {};
    debug('^9884234^', {$vnr, p, row});
    R = thaw(new_datom(row.key, {$vnr}));
    R.dest = row.dest;
    R.ref = row.ref;
    R.realm = row.realm;
    if (row.text != null) {
      R.text = row.text;
    }
    if ((ref1 = row.stamped) != null ? ref1 : false) {
      R.$stamped = true;
    }
    for (k in p) {
      if (p[k] != null) {
        R[k] = p[k];
      }
    }
    return freeze(R);
  };

  //-----------------------------------------------------------------------------------------------------------
  this._properties_from_datom = (S, d) => {
    var R, count, k, v;
    R = {};
    count = 0;
    for (k in d) {
      v = d[k];
      if (k === '$key') {
        continue;
      }
      if (k === 'text') {
        continue;
      }
      if (k === 'realm') {
        continue;
      }
      if (k === 'dest') {
        continue;
      }
      if (k === 'ref') {
        continue;
      }
      if (k.startsWith('$')) {
        continue;
      }
      if (v == null) {
        continue;
      }
      count += 1;
      R[k] = v;
    }
    if (count === 0) {
      R = null;
    }
    return JSON.stringify(R);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.row_from_datom = (S, d) => {
    var R, dest, key, p, realm, ref, ref1, ref2, ref3, ref4, ref5, stamped, text, vnr;
    key = d.$key;
    vnr = d.$vnr;
    stamped = (ref1 = d.$stamped) != null ? ref1 : false;
    dest = (ref2 = d.dest) != null ? ref2 : S.mirage.default_dest;
    text = (ref3 = d.text) != null ? ref3 : null;
    ref = (ref4 = d.ref) != null ? ref4 : null;
    realm = (ref5 = d.realm) != null ? ref5 : S.mirage.default_realm;
    p = this._properties_from_datom(S, d);
    R = {key, realm, vnr, dest, text, p, stamped, ref};
    // R         = { key, vnr, vnr_blob, dest, text, p, stamped, }
    // MIRAGE.types.validate.mirage_main_row R if do_validate
    return R;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.new_db_source = (S, ...P) => {
    var R;
    R = SP.new_push_source();
    this.feed_source(S, R, ...P);
    return R;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.feed_source = (S, source, from_realm) => {
    /* TAINT do casting in DB module */
    var dbr, first_vnr, first_vnr_blob, last_vnr, last_vnr_blob, phase, row, rows;
    dbr = S.mirage.db;
    if (from_realm == null) {
      from_realm = 'input';
    }
    //.........................................................................................................
    if (DM._is_reprising(S)) {
      validate.datamill_inclusive_region(S.control.reprise);
      ({first_vnr, last_vnr, phase} = S.control.reprise);
      first_vnr_blob = dbr.$.as_hollerith(first_vnr);
      last_vnr_blob = dbr.$.as_hollerith(last_vnr);
      rows = dbr.read_unstamped_lines({
        realm: from_realm,
        first_vnr_blob,
        last_vnr_blob
      });
    } else {
      //.........................................................................................................
      rows = dbr.read_unstamped_lines({
        realm: from_realm
      });
    }
//.........................................................................................................
    for (row of rows) {
      source.send(this.datom_from_row(S, row));
    }
    //.........................................................................................................
    source.end();
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$feed_db = (S) => {
    var dbw;
    dbw = S.mirage.dbw;
    return $watch((d) => {
      /* TAINT how to convert vnr in ICQL? */
      var changes, error, methods, row;
      row = this.row_from_datom(S, d);
      methods = [];
      try {
        /* TAINT consider to use upsert instead https://www.sqlite.org/lang_UPSERT.html */
        /* NOTE Make sure to test first for `$fresh`/inserts, then for `$dirty`/updates, since a `$fresh`
             datom may have undergone changes (which doesn't make the correct opertion an update). */
        if (d.$fresh) {
          methods.push('insert fresh');
          dbw.insert(row);
        } else if (d.$dirty) {
          /* NOTE force insert when update was without effect; this happens when `$vnr` was
                 affected by a `SP.set()` call (ex. `VNR.advance $vnr; send SP.set d, '$vnr', $vnr`). */
          methods.push('update dirty');
          ({changes} = dbw.update(row));
          if (changes === 0) {
            methods.push('insert dirty');
            dbw.insert(row);
          }
        }
      } catch (error1) {
        error = error1;
        warn('µ12133', `when trying to ${methods.join(' -> ')} row`);
        warn('µ12133', jr(row));
        warn('µ12133', "an error occurred:");
        warn('µ12133', `${error.message}`);
        if (error.message.startsWith('UNIQUE constraint failed')) {
          urge('µ88768', "conflict occurred because");
          urge('µ88768', jr(this.row_from_vnr(S, d.$vnr)));
          urge('µ88768', "is already in DB");
        }
        throw error;
      }
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$feed_memory = (S) => {
    return $watch((d) => {
      /* TAINT how to convert vnr in ICQL? */
      var changes, error, methods, row;
      row = this.row_from_datom(S, d);
      methods = [];
      try {
        /* TAINT consider to use upsert instead https://www.sqlite.org/lang_UPSERT.html */
        /* NOTE Make sure to test first for `$fresh`/inserts, then for `$dirty`/updates, since a `$fresh`
             datom may have undergone changes (which doesn't make the correct opertion an update). */
        if (d.$fresh) {
          methods.push('insert fresh');
          dbw.insert(row);
        } else if (d.$dirty) {
          /* NOTE force insert when update was without effect; this happens when `$vnr` was
                 affected by a `SP.set()` call (ex. `VNR.advance $vnr; send SP.set d, '$vnr', $vnr`). */
          methods.push('update dirty');
          ({changes} = dbw.update(row));
          if (changes === 0) {
            methods.push('insert dirty');
            dbw.insert(row);
          }
        }
      } catch (error1) {
        error = error1;
        warn('µ12133', `when trying to ${methods.join(' -> ')} row`);
        warn('µ12133', jr(row));
        warn('µ12133', "an error occurred:");
        warn('µ12133', `${error.message}`);
        if (error.message.startsWith('UNIQUE constraint failed')) {
          urge('µ88768', "conflict occurred because");
          urge('µ88768', jr(this.row_from_vnr(S, d.$vnr)));
          urge('µ88768', "is already in DB");
        }
        throw error;
      }
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$resume_from_db = function(S, settings) {
    var last, pipeline, source;
    /* `$resume_from_db()` will feed all datoms to the DB when `settings.feed_db`; when the stream has ended,
     it will then re-read from the DB (using `settings.from_realm`). This is handy to ensure that no stamped
     datoms are in the stream below this transform, and that all datoms are properly ordered. */
    /* TAINT use active realm as soon as it becomes available; use API to retrieve it */
    validate.datamill_resume_from_db_settings(settings);
    last = Symbol('last');
    source = SP.new_push_source();
    pipeline = [];
    /* TAINT make sure realm used here is same as for feed_source */
    pipeline.push(this.$set_realm_where_missing(S, settings.realm));
    pipeline.push(this.$feed_db(S));
    pipeline.push($({last}, (d, send) => {
      if (d !== last) {
        return null;
      }
      /* TAINT make sure realm used here is same as for set_realm_where_missing */
      return this.feed_source(S, source, settings.realm);
    }));
    pipeline.push(SP.$wye(source));
    return SP.pull(...pipeline);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.resume_from_db_before = function(S, settings, transform) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$resume_from_db(S, settings));
    pipeline.push(transform);
    return SP.pull(...pipeline);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.resume_from_db_after = function(S, settings, transform) {
    var pipeline;
    pipeline = [];
    pipeline.push(transform);
    pipeline.push(this.$resume_from_db(S, settings));
    return SP.pull(...pipeline);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$set_realm_where_missing = function(S, realm) {
    realm = realm != null ? realm : S.mirage.default_realm;
    return $((d, send) => {
      return send(d.realm != null ? d : SP.set(d, {realm}));
    });
  };

  //===========================================================================================================
  // PHASES
  //-----------------------------------------------------------------------------------------------------------
  this.repeat_phase = (S, phase) => {
    validate.datamill_phase_repeat(phase.repeat_phase);
    if (phase.repeat_phase == null) {
      return false;
    }
    if (isa.boolean(phase.repeat_phase)) {
      return phase.repeat_phase;
    }
    return phase.repeat_phase(S);
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$show = (S) => {
    return $watch((d) => {
      var color;
      if (d.$stamped) {
        color = CND.grey;
      } else {
        switch (d.$key) {
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
  this.get_tty_width = (S) => {
    var R, execSync;
    if ((R = process.stdout.columns) != null) {
      return R;
    }
    ({execSync} = require('child_process'));
    return parseInt(execSync("tput cols", {
      encoding: 'utf-8'
    }), 10);
  };

  //-----------------------------------------------------------------------------------------------------------
  this.show_overview = (S, settings) => {
    var dbr, i, len, realm, ref1;
    dbr = S.mirage.dbr;
    ref1 = dbr.$.all_first_values(dbr.read_realm_registry());
    for (i = 0, len = ref1.length; i < len; i++) {
      realm = ref1[i];
      info('µ13221', `Realm ${rpr(realm)}`);
      this._show_overview(S, settings, realm);
    }
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this._show_overview = (S, settings, realm) => {
    /* TAINT consider to convert row to datom before display */
    var _color, color, combi, dbr, defaults, dent, dest, key, level, line, line_width, omit_count, p, properties, ref, ref1, ref2, ref3, ref4, ref5, row, show_blanks, show_stamped, sid, star, text, value, vnr, xxx_deemphasize_closing_tags, xxxxx;
    line_width = this.get_tty_width(S);
    dbr = S.mirage.db;
    level = 0;
    omit_count = 0;
    show_stamped = true;
    show_blanks = true;
    xxx_deemphasize_closing_tags = false;
    //.........................................................................................................
    defaults = {
      raw: false,
      hilite: null
    };
    settings = assign({}, defaults, settings);
    ref1 = dbr.read_lines({realm});
    // { limit: 30, }
    //.........................................................................................................
    for (row of ref1) {
      if (settings.raw) {
        info(this.format_object(row));
        continue;
      }
      if ((row.$key === '^line') && row.stamped && (row.text === '')) {
        omit_count += +1;
        continue;
      }
      if ((!show_blanks) && (row.$key === '^blank')) {
        omit_count += +1;
        continue;
      }
      if ((!show_stamped) && row.stamped) {
        omit_count += +1;
        continue;
      }
      switch (row.$key) {
        case '^line':
          _color = CND.YELLOW;
          break;
        case '^block':
          _color = CND.gold;
          break;
        case '^mktscript':
          _color = CND.ORANGE;
          break;
        case '~warning':
          _color = CND.RED;
          break;
        case '~notice':
          _color = CND.cyan;
          break;
        case '^literal':
          _color = CND.GREEN;
          break;
        case '^literal-blank':
          _color = CND.GREEN;
          break;
        case '<h':
          _color = CND.VIOLET;
          break;
        case '>h':
          _color = CND.VIOLET;
          break;
        case '^html':
          _color = CND.BLUE;
          break;
        case '<p':
        case '>p':
          _color = CND.grey;
          break;
        default:
          _color = this.color_from_text(row.$key.slice(1));
      }
      //.......................................................................................................
      star = row.stamped ? '*' : '';
      key = to_width(row.$key, 15);
      sid = to_width(`${row.sid}`, 2);
      realm = to_width(row.realm, 6);
      vnr = to_width(star + row.$vnr, 12);
      dest = to_width(row.dest, 4);
      ref = to_width((ref2 = row.ref) != null ? ref2 : '', 13);
      text = row.text != null ? jr(row.text) : null;
      p = (ref3 = row.p) != null ? ref3 : null;
      if (p === 'null') {
        p = null;
      }
      //.......................................................................................................
      combi = [];
      if (text != null) {
        combi.push(text);
      }
      if (p != null) {
        combi.push(p);
      }
      value = combi.join(' / ');
      // value   = value[ .. 80 ]
      line = `${sid}${realm}${vnr}│${dest}│${ref}│${key}│${value}`;
      line = to_width(line, line_width);
      dent = '  '.repeat(level);
      level = (function() {
        switch (row.$key[0]) {
          case '<':
            return level + 1;
          case '>':
            return level - 1;
          default:
            return level;
        }
      })();
      level = Math.max(level, 0);
      //.......................................................................................................
      if ((settings.hilite != null) && (settings.hilite === row.$key)) {
        color = function(...P) {
          return CND.reverse(CND.pink(...P));
        };
      } else if (row.stamped) {
        color = CND.grey;
      } else if (row.$key === '^blank') {
        color = CND.yellow;
      } else {
        if (xxx_deemphasize_closing_tags) {
          if (row.$key[0] === '>') {
            color = function(...P) {
              return _color(...P);
            };
          } else {
            color = function(...P) {
              return CND.reverse(_color(...P));
            };
          }
        } else {
          color = function(...P) {
            return CND.reverse(_color(...P));
          };
        }
      }
      //.......................................................................................................
      /* TAINT experimental, needs better implementation */
      if ((properties = row.p) != null) {
        properties = (ref4 = JSON.parse(properties)) != null ? ref4 : {};
      } else {
        properties = {};
      }
      xxxxx = 56;
      if (row.stamped) {
        echo((color(line.slice(0, xxxxx))) + CND.grey(line.slice(xxxxx)));
      } else if (line[xxxxx] === '"') {
        echo((color(line.slice(0, xxxxx))) + CND.reverse(CND.YELLOW(line.slice(xxxxx))));
      } else if (properties.error != null) {
        echo((color(line.slice(0, xxxxx))) + CND.reverse(CND.pink(to_width(properties.error, line_width - xxxxx))));
      } else {
        echo((color(line.slice(0, xxxxx))) + CND.YELLOW(line.slice(xxxxx)));
      }
    }
    // echo dent + color line
    //.........................................................................................................
    echo(`${omit_count} rows omitted from this view`);
    ref5 = dbr.get_stats();
    for (row of ref5) {
      echo(`${row.$key}: ${row.count}`);
    }
    //.........................................................................................................
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  _color_cache = {};

  this.color_from_text = function(text) {
    var R;
    if ((R = _color_cache[text]) != null) {
      return R;
    }
    R = function(...P) {
      return (XXX_COLORIZER.ansi_code_from_text(text)) + CND._pen(...P);
    };
    // R = ( P... ) -> CND.reverse ( XXX_COLORIZER.ansi_code_from_text text ) + CND._pen P...
    _color_cache[text] = R;
    return R;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.show_html = function(datamill) {
    var $vnr, blank, d, db, i, idx, len, line_width, lnr, lnr_color, lnr_rpr, lnr_width, ref1, row, text, text_color, text_rpr, text_width, texts;
    line_width = this.get_tty_width(null);
    db = datamill.mirage.db;
    ref1 = db.$.query("select * from main where key = '^html' order by vnr_blob;");
    for (row of ref1) {
      d = this.datom_from_row(datamill, row);
      ({text, $vnr} = d);
      lnr = $vnr[0];
      texts = text.split('\n');
      lnr_width = 4;
      text_width = line_width - lnr_width - 3;
      text_color = function(...P) {
        return CND.reverse(CND.BLUE(...P));
      };
      lnr_color = function(...P) {
        return CND.reverse(CND.grey(...P));
      };
      blank = lnr_color((''.padStart(lnr_width)) + ' │');
//.......................................................................................................
      for (idx = i = 0, len = texts.length; i < len; idx = ++i) {
        text = texts[idx];
        text_rpr = text_color(' ' + to_width(text, text_width));
        if ((idx === 0) && ((text.match('^\s*$')) == null)) {
          lnr_rpr = lnr_color((`${lnr}`.padStart(lnr_width)) + ' │');
          echo(`${lnr_rpr}${text_rpr}`);
        } else {
          echo(`${blank}${text_rpr}`);
        }
      }
    }
    //.........................................................................................................
    return null;
  };

}).call(this);

//# sourceMappingURL=helpers.js.map