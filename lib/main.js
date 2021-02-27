(function() {
  'use strict';
  var $, $async, $watch, CND, DATAMILL, H, MIRAGE, PD, VNR, assign, badge, cwd_abspath, cwd_relpath, debug, declare, echo, first, first_of, help, here_abspath, info, isa, jr, last, last_of, project_abspath, rpr, select, size_of, stamp, type_of, urge, validate, warn, whisper;

  //###########################################################################################################
  CND = require('cnd');

  rpr = CND.rpr;

  badge = 'DATAMILL/MAIN';

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  info = CND.get_logger('info', badge);

  urge = CND.get_logger('urge', badge);

  help = CND.get_logger('help', badge);

  whisper = CND.get_logger('whisper', badge);

  echo = CND.echo.bind(CND);

  ({jr, assign} = CND);

  //...........................................................................................................
  debug('^3334-1^');

  first = Symbol('first');

  last = Symbol('last');

  debug('^3334-2^');

  MIRAGE = require('mkts-mirage');

  debug('^3334-3^');

  VNR = require('./vnr');

  debug('^3334-4^');

  //...........................................................................................................
  PD = require('pipedreams');

  debug('^3334-5^');

  ({$, $watch, $async, select, stamp} = PD.export());

  debug('^3334-6^');

  //...........................................................................................................
  this.types = require('./types');

  ({isa, validate, declare, first_of, last_of, size_of, type_of} = this.types);

  debug('^3334-7^');

  //...........................................................................................................
  H = require('./helpers');

  debug('^3334-8^');

  ({cwd_abspath, cwd_relpath, here_abspath, project_abspath} = H);

  DATAMILL = this;

  debug('^3334-9^');

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.run_phase = function(S, settings, transform) {
    return new Promise((resolve, reject) => {
      var R, defaults, pipeline, source;
      defaults = {
        from_realm: S.mirage.default_realm
      };
      settings = {...defaults, ...settings};
      validate.datamill_run_phase_settings(settings);
      // debug 'µ33344', jr S
      // source    = H.new_db_source S
      // pipeline  = []
      // pipeline.push source
      // pipeline.push transform
      // pipeline.push H.$feed_db S
      // pipeline.push PD.$drain => resolve()
      // R = PD.pull pipeline...
      source = PD.new_push_source();
      pipeline = [];
      pipeline.push(source);
      pipeline.push(transform);
      pipeline.push(H.$feed_db(S));
      pipeline.push(PD.$drain(() => {
        return resolve();
      }));
      R = PD.pull(...pipeline);
      H.feed_source(S, source, settings.from_realm);
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  /* TAINT consider to use dedicated DB module akin to mkts-mirage/src/db.coffee */
  this._create_udfs = function(mirage) {
    var db;
    db = mirage.db;
    /* Placeholder function re-defined by `H.copy_realm()`: */
    db.$.function('datamill_copy_realm_select', {
      deterministic: false,
      varargs: false
    }, function(row) {
      return true;
    });
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.create = async function(settings) {
    var R, defaults, mirage;
    /* TAINT set active realm */
    debug('^3334-10^');
    defaults = {
      file_path: null,
      // db_path:        ':memory:'
      db_path: H.project_abspath('db/datamill.db'),
      icql_path: H.project_abspath('db/datamill.icql'),
      default_key: '^line',
      default_dest: 'main',
      default_realm: 'input',
      clear: true
    };
    //.........................................................................................................
    debug('^3334-11^');
    settings = {...defaults, ...settings};
    mirage = (await MIRAGE.create(settings));
    debug('^3334-12^');
    //.........................................................................................................
    R = {
      mirage: mirage,
      control: {
        active_phase: null,
        queue: [],
        /* A queue for flow control messages */reprise_nr: 1,
        reprise: {
          start_vnr: null,
          stop_vnr: null,
          phase: null
        }
      }
    };
    //.........................................................................................................
    /* TAINT consider to use dedicated DB module akin to mkts-mirage/src/db.coffee */
    this./* name of phase that queued control messages */_create_udfs(mirage);
    debug('^3334-13^');
    return R;
  };

  //-----------------------------------------------------------------------------------------------------------
  this._set_active_phase = (S, phase_name) => {
    return S.control.active_phase = phase_name;
  };

  this._cancel_active_phase = (S) => {
    return S.control.active_phase = null;
  };

  this._length_of_control_queue = (S) => {
    return S.control.queue.length;
  };

  this._control_queue_has_messages = (S) => {
    return (this._length_of_control_queue(S)) > 0;
  };

  this._next_control_message_is_from = (S, phase_name) => {
    var ref1;
    return ((ref1 = S.control.queue[0]) != null ? ref1.phase : void 0) === phase_name;
  };

  this._is_reprising = (S) => {
    return S.control.reprise.phase != null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this._set_to_reprising = (S, message) => {
    validate.datamill_reprising_message(message);
    assign(S.control.reprise.phase, message);
    S.control.reprise_nr += +1;
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this._conclude_current_reprise = (S) => {
    var key;
    for (key in S.control.reprise) {
      S.control.reprise[key] = null;
    }
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this._pluck_next_control_message = (S) => {
    var message;
    if (!(S.control.queue.length > 0)) {
      throw new Error("µ11092 queue is empty");
    }
    message = S.control.queue.shift();
    assign(S.control.reprise, message);
    return message;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.reprise = (S, region) => {
    var first_vnr, last_vnr, ref;
    validate.datamill_inclusive_region(region);
    validate.nonempty_text(S.control.active_phase);
    /* TAINT use explicit datatype to test for additional condition */
    validate.nonempty_text(region.ref);
    ({first_vnr, last_vnr, ref} = region);
    S.control.queue.push(PD.new_datom('~reprise', {
      first_vnr,
      last_vnr,
      phase: S.control.active_phase,
      ref
    }));
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.render_html = function(S, settings) {
    return new Promise(async(resolve, reject) => {
      var defaults;
      defaults = {
        phase_names: ['./900-render-html']
      };
      settings = {...defaults, ...settings};
      return resolve((await this.parse_document(S, settings)));
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.parse_document = function(S, settings) {
    return new Promise(async(resolve, reject) => {
      var defaults, i, len, message, msg_1, msg_2, msg_2a, msg_3, pass, phase, phase_name, ref1, ref2;
      defaults = {
        quiet: false,
        phase_names: [
          './000-initialize',
          './005-start-stop',
          './006-ignore',
          './010-1-whitespace',
          './010-2-whitespace-dst',
          './020-blocks',
          './030-paragraphs',
          './035-hunks',
          './040-markdown-inline',
          // # './030-escapes'
          // # './035-special-forms'
          './xxx-validation'
        ]
      };
      // './900-render-html'
      settings = {...defaults, ...settings};
      validate.datamill_parse_document_settings(settings);
      //.........................................................................................................
      msg_1 = function() {
        var nrs_txt;
        if (settings.quiet) {
          return;
        }
        nrs_txt = CND.reverse(CND.yellow(` r${S.control.reprise_nr} p${pass} `));
        return help('µ55567 ' + nrs_txt + (CND.lime(` phase ${phase_name} `)));
      };
      //.........................................................................................................
      msg_2 = function(phase_name) {
        var nrs_txt;
        if (settings.quiet) {
          return;
        }
        nrs_txt = CND.reverse(CND.yellow(` r${S.control.reprise_nr} `));
        info('µ22872', nrs_txt + CND.blue(` finished reprise for ${phase_name}`));
        return info();
      };
      //.........................................................................................................
      msg_2a = function(phase_name) {
        if (settings.quiet) {
          return;
        }
        info('µ22872', CND.blue("continuing without limits"));
        return info();
      };
      //.........................................................................................................
      msg_3 = function(message) {
        var nrs_txt;
        if (settings.quiet) {
          return;
        }
        nrs_txt = CND.reverse(CND.yellow(` r${S.control.reprise_nr} `));
        info();
        return info('µ33324', nrs_txt + CND.blue(` reprise for ${message.phase} with fragment ${jr(message.first_vnr)} <= vnr <= ${jr(message.last_vnr)} (ref: ${message.ref})`));
      };
      while (true) {
        try {
          ref1 = settings.phase_names;
          // ### TAINT use API ###
          // S.confine_to = null
          // S.confine_from_phase = null
          //.........................................................................................................
          for (i = 0, len = ref1.length; i < len; i++) {
            phase_name = ref1[i];
            this._set_active_phase(S, phase_name);
            // length_of_queue = @_length_of_control_queue S
            phase = require(phase_name);
            pass = 1;
            msg_1();
            await this.run_phase(S, (ref2 = phase.settings) != null ? ref2 : null, phase.$transform(S));
            //...................................................................................................
            if (S.control.reprise.phase === phase_name) {
              /* Conclude reprise; continue with upcoming phase and entire document */
              /* TAINT do we have to stack boundaries? */
              msg_2(phase_name);
              this._conclude_current_reprise(S);
            }
            //...................................................................................................
            if (this._next_control_message_is_from(S, phase_name)) {
              throw this._pluck_next_control_message(S);
            }
            // msg_2a() unless @_control_queue_has_messages S
            //...................................................................................................
            if (H.repeat_phase(S, phase)) {
              throw new Error(`µ33443 phase repeating not implemented (${rpr(phase_name)})`);
            }
            this._cancel_active_phase(S);
          }
        } catch (error) {
          //.......................................................................................................
          message = error;
          if (!(select(message, '~reprise'))) {
            throw message;
          }
          this._set_to_reprising(S, message);
          msg_3(message);
          /* TAINT use API */
          continue;
        }
        break;
      }
      //.........................................................................................................
      resolve();
      //.........................................................................................................
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this._demo_list_html_rows = function(S) {
    return new Promise((resolve) => {
      var pipeline;
      //.......................................................................................................
      pipeline = [];
      pipeline.push(H.new_db_source(S, 'html'));
      pipeline.push(PD.$show());
      pipeline.push(PD.$drain(function() {
        return resolve();
      }));
      return PD.pull(...pipeline);
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this._demo = async function() {
    debug('^3334-14^');
    await (() => {
      return new Promise(async(resolve) => {
        var HTML, datamill, quiet, settings;
        //.......................................................................................................
        debug('^3334-15^');
        settings = {
          // file_path:      project_abspath 'src/tests/demo-short-headlines.md'
          // file_path:      project_abspath 'src/tests/demo.md'
          file_path: project_abspath('src/tests/demo-medium.md')
        };
        // file_path:      project_abspath 'src/tests/demo-simple-paragraphs.md'
        //.......................................................................................................
        debug('^3334-16^');
        help(`using database at ${settings.db_path}`);
        debug('^3334-17^');
        datamill = (await DATAMILL.create(settings));
        debug('^3334-18^');
        quiet = false;
        quiet = true;
        await DATAMILL.parse_document(datamill, {quiet});
        await this.render_html(datamill, {quiet});
        // await @_demo_list_html_rows         datamill
        //.......................................................................................................
        await H.show_overview(datamill);
        await H.show_html(datamill);
        HTML = require('./900-render-html');
        await HTML.write_to_file(datamill);
        resolve();
        return null;
      });
    })();
    return null;
  };

  //###########################################################################################################
  if (module === require.main) {
    (async() => {
      debug('^3334-19^');
      return (await DATAMILL._demo());
    })();
  }

}).call(this);

//# sourceMappingURL=main.js.map