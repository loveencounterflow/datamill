(function() {
  'use strict';
  var DBay, GUY, Intertype, PATH, base_types, debug, document_types, echo, get_base_types, get_document_types, get_server_types, inspect, log, misfit, rpr, server_types;

  //###########################################################################################################
  GUY = require('guy');

  // { alert
  //   debug
  //   help
  //   info
  //   plain
  //   praise
  //   urge
  //   warn
  //   whisper }               = GUY.trm.get_loggers 'DATAMILL/TYPES'
  ({debug} = GUY.trm.get_loggers('DATAMILL/TYPES'));

  ({rpr, inspect, echo, log} = GUY.trm);

  ({Intertype} = require('intertype'));

  base_types = null;

  server_types = null;

  document_types = null;

  misfit = Symbol('misfit');

  PATH = require('node:path');

  ({DBay} = require('dbay'));

  //-----------------------------------------------------------------------------------------------------------
  get_base_types = function() {
    var declare;
    if (base_types != null) {
      return base_types;
    }
    //.........................................................................................................
    base_types = new Intertype();
    ({declare} = base_types);
    //.........................................................................................................
    declare.dbay({
      override: true,
      isa: function(x) {
        var ref;
        return (x != null ? (ref = x.constructor) != null ? ref.name : void 0 : void 0) === 'DBay';
      }
    });
    /* TAINT should check whether collides with any other prefix */
    declare.dbay_prefix({
      isa: function(x) {
        return (this.isa.text(x)) && (x.endsWith('_'));
      }
    });
    //.........................................................................................................
    return base_types;
  };

  //-----------------------------------------------------------------------------------------------------------
  get_server_types = function() {
    var declare;
    if (server_types != null) {
      return server_types;
    }
    //.........................................................................................................
    server_types = new Intertype(get_base_types());
    ({declare} = server_types);
    //.........................................................................................................
    declare.datamill_host('nonempty.text');
    declare.datamill_port(function(x) {
      if (!this.isa.integer(x)) {
        return false;
      }
      if (!((1024 <= x && x <= 65535))) {
        return false;
      }
      return true;
    });
    //.........................................................................................................
    declare.datamill_server_cfg({
      fields: {
        host: 'datamill_host',
        port: 'datamill_port',
        db: 'dbay'
      },
      default: {
        host: 'localhost',
        port: 3456,
        paths: {
          public: PATH.resolve(__dirname, '../public'),
          favicon: PATH.resolve(__dirname, '../public/favicon.png'),
          src: PATH.resolve(__dirname, '../src')
        },
        file_server: {
          // Enable or disable accepting ranged requests. Disabling this will not send Accept-Ranges and ignore the
          // contents of the Range request header. defaults to true.
          acceptRanges: true,
          // Set Cache-Control response header, defaults to undefined, see docs: Cache-Control in MDN.
          cacheControl: void 0,
          // Enable or disable etag generation, defaults to true.
          etag: true,
          // Enable or disable Last-Modified header, defaults to true. Uses the file system's last modified value.
          // defaults to true.
          lastModified: true,
          // Set ignore rules. defaults to undefined. ( path ) => boolean
          ignore: void 0,
          // If true, serves after await next(), allowing any downstream middleware to respond first. defaults to false.
          defer: false
        }
      }
    });
    //...........................................................................................................
    return server_types;
  };

  //-----------------------------------------------------------------------------------------------------------
  get_document_types = function() {
    var declare;
    if (document_types != null) {
      return document_types;
    }
    //.........................................................................................................
    document_types = new Intertype(get_base_types());
    ({declare} = document_types);
    //.........................................................................................................
    declare.doc_document_cfg({
      fields: {
        db: 'dbay',
        prefix: 'dbay_prefix'
      },
      default: {
        db: null,
        prefix: 'doc_'
      },
      create: function(x) {
        var R;
        if (!((x == null) || (this.isa.object(x)))) {
          return x;
        }
        R = {...this.registry.doc_document_cfg.default, ...x};
        if (R.db == null) {
          R.db = new DBay();
        }
        if (R.file_adapters == null) {
          R.file_adapters = (require('./document')).file_adapters;
        }
        return R;
      }
    });
    //...........................................................................................................
    declare.new_external_file_cfg({
      isa: 'anything'
    });
    //...........................................................................................................
    declare.new_external_text_file_cfg({
      isa: 'anything'
    });
    //...........................................................................................................
    return document_types;
  };

  module.exports = {misfit, get_base_types, get_server_types, get_document_types};

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_dsk', tests:
//   "@isa.nonempty_text x":     ( x ) -> @isa.nonempty_text x

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_sid', tests:
//   "@isa.positive_integer x":  ( x ) -> @isa.positive_integer x

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_db_constructor_cfg', tests:
//   "@isa.object x":                                  ( x ) -> @isa.object x
//   "( @isa.object x.db ) or ( @isa.function x.db ":  ( x ) -> ( @isa.object x.db ) or ( @isa.function x.db )
//   "@isa.nonempty_text x.prefix":                    ( x ) -> @isa.nonempty_text x.prefix
// #...........................................................................................................
// @defaults.datamill_db_constructor_cfg =
//   db:               null
//   prefix:           'vogue'

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scrapers_constructor_cfg', tests:
//   "@isa.object x":                                  ( x ) -> @isa.object x
// #...........................................................................................................
// @defaults.datamill_scrapers_constructor_cfg = {}

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scrapers_add_cfg', tests:
//   "@isa.object x":                                  ( x ) -> @isa.object x
//   "@isa.object x.scraper":                          ( x ) -> @isa.object x.scraper
// #...........................................................................................................
// @defaults.datamill_scrapers_add_cfg =
//   scraper:          null

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scraper_constructor_cfg', tests:
//   "@isa.object x":                                  ( x ) -> @isa.object x
//   "@isa.nonempty_text x.encoding":                  ( x ) -> @isa.nonempty_text x.encoding
//   "@isa.datamill_dsk x.dsk":                           ( x ) -> @isa.datamill_dsk x.dsk
//   "@isa_optional.nonempty_text x.url":              ( x ) -> @isa_optional.nonempty_text x.url
// #...........................................................................................................
// @defaults.datamill_scraper_constructor_cfg =
//   encoding:         'utf-8'
//   dsk:              null
//   url:              null

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scraper__XXX_get_details_chart_cfg', tests:
//   "@isa.object x":                                  ( x ) -> @isa.object x
//   "@isa.datamill_dsk x.dsk":                           ( x ) -> @isa.datamill_dsk x.dsk
// #...........................................................................................................
// @defaults.datamill_scraper__XXX_get_details_chart_cfg =
//   dsk:              null

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scraper__XXX_get_details_table_cfg', tests:
//   "@isa.object x":                                  ( x ) -> @isa.object x
//   "@isa.datamill_dsk x.dsk":                           ( x ) -> @isa.datamill_dsk x.dsk
// #...........................................................................................................
// @defaults.datamill_scraper__XXX_get_details_table_cfg =
//   dsk:              null

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_hub_constructor_cfg', tests:
//   "@isa.object x":                                  ( x ) -> @isa.object x
//   "@isa.datamill_db x.vdb":                            ( x ) -> @isa.datamill_db x.vdb
//   "@isa.datamill_server x.server":                     ( x ) -> @isa.datamill_server x.server
//   "@isa.datamill_scrapers x.scrapers":                 ( x ) -> @isa.datamill_scrapers x.scrapers
// #...........................................................................................................
// @defaults.datamill_hub_constructor_cfg =
//   vdb:                null
//   server:             null
//   scrapers:           null

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scheduler_constructor_cfg', tests:
//   "@isa.object x":                                  ( x ) -> @isa.object x
// #...........................................................................................................
// @defaults.datamill_scheduler_constructor_cfg = {}

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scheduler_abs_duration', tests:
//   "@isa.nonempty_text x":         ( x ) -> @isa.nonempty_text x
//   "x matches float, unit regex":  ( x ) ->
//     pattern     = ( require './vogue-scheduler' ).Vogue_scheduler.C.abs_duration_pattern
//     units       = ( require './vogue-scheduler' ).Vogue_scheduler.C.duration_units
//     return false unless ( match = x.match pattern )?
//     return false unless match.groups.unit in units
//     return true

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scheduler_rel_duration', tests:
//   "@isa.nonempty_text x":         ( x ) -> @isa.nonempty_text x
//   "x matches precentage pattern": ( x ) ->
//     pattern     = ( require './vogue-scheduler' ).Vogue_scheduler.C.percentage_pattern
//     return ( match = x.match pattern )?

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scheduler_absrel_duration', ( x ) ->
//   return true if @isa.datamill_scheduler_abs_duration  x
//   return true if @isa.datamill_scheduler_rel_duration  x
//   return false

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scheduler_task', ( x ) ->
//   return true if @isa.function      x
//   return true if @isa.asyncfunction x
//   return false

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_scheduler_add_interval_cfg', tests:
//   "@isa.object x":                                ( x ) -> @isa.object x
//   "@isa.datamill_scheduler_task x.task":             ( x ) -> @isa.datamill_scheduler_task x.task
//   "@isa.datamill_scheduler_abs_duration x.repeat":       ( x ) -> @isa.datamill_scheduler_abs_duration x.repeat
//   "@isa.datamill_scheduler_absrel_duration x.jitter":    ( x ) -> @isa.datamill_scheduler_absrel_duration x.jitter
//   # "@isa.datamill_scheduler_absrel_duration x.timeout":   ( x ) -> @isa.datamill_scheduler_abs_duration x.timeout
//   "@isa.datamill_scheduler_absrel_duration x.pause":     ( x ) -> @isa.datamill_scheduler_absrel_duration x.pause
// #...........................................................................................................
// @defaults.datamill_scheduler_add_interval_cfg =
//   task:             null
//   repeat:           null
//   jitter:           '0 seconds'
//   pause:            '0 seconds'
//   # timeout:          null

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_html_or_buffer', tests:
//   "@type_of x in [ 'text', 'buffer', ]":  ( x ) -> @type_of x in [ 'text', 'buffer', ]

  // #-----------------------------------------------------------------------------------------------------------
// declare 'datamill_db_trends_data_json_from_dsk_sid_cfg', tests:
//   "@isa.object x":                                  ( x ) -> @isa.object x
//   "@isa.datamill_dsk x.dsk":                           ( x ) -> @isa.datamill_dsk x.dsk
//   "@isa_optional.datamill_sid x.sid":                  ( x ) -> @isa_optional.datamill_sid x.sid
// #...........................................................................................................
// @defaults.datamill_db_trends_data_json_from_dsk_sid_cfg =
//   dsk:              null
//   sid:              null

}).call(this);

//# sourceMappingURL=types.js.map