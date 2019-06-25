(function() {
  'use strict';
  var $, $drain, $fresh, $show, $watch, CND, DATAMILL, FS, H, PD, VNR, badge, debug, declare, echo, first, first_of, help, info, isa, jr, last, last_of, rpr, select, size_of, stamp, type_of, urge, validate, warn, whisper;

  //###########################################################################################################
  CND = require('cnd');

  rpr = CND.rpr;

  badge = 'DATAMILL/TESTS/DB-BENCHMARK';

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  info = CND.get_logger('info', badge);

  urge = CND.get_logger('urge', badge);

  help = CND.get_logger('help', badge);

  whisper = CND.get_logger('whisper', badge);

  echo = CND.echo.bind(CND);

  //...........................................................................................................
  jr = JSON.stringify;

  //...........................................................................................................
  PD = require('pipedreams');

  ({$, $watch, $show, $drain, stamp, select} = PD);

  H = require('../helpers');

  DATAMILL = require('../..');

  ({isa, validate, declare, first_of, last_of, size_of, type_of} = DATAMILL.types);

  VNR = require('../vnr');

  $fresh = true;

  first = Symbol('first');

  last = Symbol('last');

  FS = require('fs');

  //-----------------------------------------------------------------------------------------------------------
  declare('datamill_db_benchmark_settings', function(x) {
    return {
      tests: {
        "x is a object": function(x) {
          return this.isa.object(x);
        },
        "x.resume_from_db is a boolean": function(x) {
          return this.isa.boolean(x.resume_from_db);
        },
        "x.n is a count": function(x) {
          return this.isa.count(x.n);
        },
        "x.text is a text": function(x) {
          return this.isa.text(x.text);
        }
      }
    };
  });

  //-----------------------------------------------------------------------------------------------------------
  this.wrap_transform = function(S, settings, transform) {
    if (settings.resume_from_db) {
      return H.resume_from_db_after(S, {
        realm: 'input'
      }, transform);
    }
    return transform;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$t1 = function(S, settings, X) {
    return this.wrap_transform(S, settings, $(function(d, send) {
      var text;
      if (!select(d, '^mktscript')) {
        // help 'µ12111-1', jr d
        return send(d);
      }
      X.count++;
      send(stamp(d));
      text = d.text.toUpperCase();
      send(PD.set(VNR.deepen(d), {
        text,
        ref: 'bnch/t1',
        $fresh
      }));
      return null;
    }));
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$t2 = function(S, settings, X) {
    return this.wrap_transform(S, settings, $(function(d, send) {
      var text;
      if (!select(d, '^mktscript')) {
        // urge 'µ12111-2', jr d
        return send(d);
      }
      X.count++;
      send(stamp(d));
      text = '*' + d.text + '*';
      send(PD.set(VNR.deepen(d), {
        text,
        ref: 'bnch/t1',
        $fresh
      }));
      return null;
    }));
  };

  //-----------------------------------------------------------------------------------------------------------
  this.benchmark = function(settings) {
    return new Promise(async(resolve) => {
      var X, datamill, dt, dts, dts_txt, n, ops, ops_txt, score, score_txt, t0, t1;
      validate.datamill_db_benchmark_settings(settings);
      n = 5;
      //.........................................................................................................
      t0 = null;
      X = {
        count: 0
      };
      datamill = (await this.create_and_populate_db({
        text: settings.text
      }));
      await (() => {        //.........................................................................................................
        return new Promise((resolve) => {
          var pipeline;
          pipeline = [];
          pipeline.push(H.new_db_source(datamill, 'input'));
          pipeline.push(this.$t1(datamill, settings, X));
          pipeline.push(this.$t2(datamill, settings, X));
          // pipeline.push $show()
          pipeline.push($watch({first}, function(d) {
            if (d === first) {
              return t0 = Date.now();
            }
          }));
          pipeline.push(H.$feed_db(datamill));
          pipeline.push($drain(function() {
            return resolve();
          }));
          help('µ66743', "starting");
          return PD.pull(...pipeline);
        });
      })();
      //.........................................................................................................
      t1 = Date.now();
      dt = Math.max(1, t1 - t0);
      dts = dt / 1000;
      ops = (X.count / dt) * 1000;
      score = ops / 10000;
      dts_txt = dts.toFixed(1);
      ops_txt = ops.toFixed(1);
      score_txt = score.toFixed(3);
      help();
      help('µ34422', `resuming: ${CND.truth(settings.resume_from_db)}`);
      help('µ34422', `n: ${settings.n}`);
      help('µ34422', `needed ${dts_txt} s for ${X.count} operations`);
      help('µ34422', `${ops_txt} operations per second`);
      help('µ34422', `score ${score_txt} (bigger is better)`);
      return resolve(datamill);
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.create_and_populate_db = function(settings) {
    return new Promise(async(resolve) => {
      var datamill, dt, dts, dts_txt, quiet, t0, t1;
      t0 = Date.now();
      FS.unlinkSync(H.project_abspath('db/datamill.db'));
      datamill = (await DATAMILL.create(settings));
      quiet = false;
      quiet = true;
      await DATAMILL.parse_document(datamill, {quiet});
      t1 = Date.now();
      dt = Math.max(1, t1 - t0);
      dts = dt / 1000;
      dts_txt = dts.toFixed(1);
      whisper(`µ33442 needed ${dts_txt} s to prepare DB`);
      // await DATAMILL.render_html          datamill, { quiet, }
      // await @_demo_list_html_rows         datamill
      //.......................................................................................................
      // await H.show_overview               datamill
      // await H.show_html                   datamill
      return resolve(datamill);
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.get_random_words = function(n = 10, path = null) {
    var CP, word, words;
    validate.count(n);
    if (path == null) {
      path = '/usr/share/dict/words';
    }
    CP = require('child_process');
    words = ((CP.execSync(`shuf -n ${n} ${path}`)).toString('utf-8')).split('\n');
    words = (function() {
      var i, len, results;
      results = [];
      for (i = 0, len = words.length; i < len; i++) {
        word = words[i];
        results.push(word.replace(/'s$/g, ''));
      }
      return results;
    })();
    words = (function() {
      var i, len, results;
      results = [];
      for (i = 0, len = words.length; i < len; i++) {
        word = words[i];
        if (word !== '') {
          results.push(word);
        }
      }
      return results;
    })();
    return words;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.get_random_text = function(n = 10, path = null) {
    var word, words;
    words = this.get_random_words(n, '/usr/share/dict/italian');
    words = (function() {
      var i, len, results;
      results = [];
      for (i = 0, len = words.length; i < len; i++) {
        word = words[i];
        results.push(Math.random() > 0.7 ? '' : word);
      }
      return results;
    })();
    return words.join('\n');
  };

  //###########################################################################################################
  if (module.parent == null) {
    (async() => {      // test @[ "benchmark" ], { timeout: 20, }
      // file_path:      project_abspath 'src/tests/demo-short-headlines.md'
      // file_path:      project_abspath 'src/tests/demo.md'
      // file_path:      project_abspath 'src/tests/demo-medium.md'
      // file_path:      project_abspath 'src/tests/demo-simple-paragraphs.md'
      var datamill, n, text;
      n = 1000;
      text = this.get_random_text(n, '/usr/share/dict/italian');
      datamill = (await this.benchmark({
        n,
        text,
        resume_from_db: true
      }));
      return datamill = (await this.benchmark({
        n,
        text,
        resume_from_db: false
      }));
    })();
  }

  // await H.show_overview datamill

}).call(this);
