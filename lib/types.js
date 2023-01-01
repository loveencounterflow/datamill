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
    var Document, declare;
    if (base_types != null) {
      return base_types;
    }
    //.........................................................................................................
    base_types = new Intertype();
    ({declare} = base_types);
    ({Document} = require('./document'));
    //.........................................................................................................
    declare.dbay({
      override: true,
      isa: function(x) {
        var ref;
        return (x != null ? (ref = x.constructor) != null ? ref.name : void 0 : void 0) === 'DBay';
      }
    });
    declare.datamill_document({
      override: true,
      isa: function(x) {
        return x instanceof Document;
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
        doc: 'datamill_document'
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
    declare.doc_fad_id('nonempty.text');
    /* TAINT should check with DB whether known */    declare.doc_src_path('nonempty.text');
    /* TAINT should be more precise */    declare.doc_src_id('nonempty.text');
    /* TAINT should be more precise */    declare.doc_region_id('nonempty.text');
    /* TAINT should be more precise */    declare.doc_home('nonempty.text');
    /* TAINT should be more precise */    declare.doc_src_hash(function(x) {
      return (this.isa.text(x)) && (/^[0-9a-f]{17}$/.test(x));
    });
    //.........................................................................................................
    declare.doc_document_cfg({
      fields: {
        db: 'dbay',
        home: 'doc_home',
        _loc_marker_re: 'regex'
      },
      default: {
        db: null,
        home: null,
        /* TAINT use more permissive identifier syntax */
        _loc_marker_re: /<(?<left_slash>\/?)dm:loc#(?<doc_loc_id>[-_a-zA-Z0-9]*)(?<right_slash>\/?)>/ug
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
        return R;
      }
    });
    //...........................................................................................................
    declare.doc_add_source_cfg({
      fields: {
        doc_src_id: 'doc_src_id',
        doc_src_path: 'doc_src_path',
        doc_src_hash: 'optional.doc_src_hash'
      },
      // doc_fad_id:         'doc_fad_id'
      default: {
        doc_src_id: null,
        doc_src_path: null,
        doc_src_hash: null
      }
    });
    // doc_fad_id:         null
    //...........................................................................................................
    declare.doc_update_source_cfg({
      fields: {
        doc_src_id: 'doc_src_id',
        doc_src_path: 'doc_src_path',
        doc_src_hash: 'doc_src_hash'
      },
      default: {
        doc_src_id: null,
        doc_src_path: null,
        doc_src_hash: null
      }
    });
    //...........................................................................................................
    declare.walk_raw_lines_cfg({
      isa: 'optional.list.of.nonempty.text',
      create: function(x) {
        if (!x) {
          return [];
        }
        return x;
      }
    });
    //...........................................................................................................
    declare.walk_xxx_lines_cfg({
      isa: 'optional.list.of.nonempty.text',
      create: function(x) {
        if (!x) {
          return [];
        }
        return x;
      }
    });
    //...........................................................................................................
    return document_types;
  };

  module.exports = {misfit, get_base_types, get_server_types, get_document_types};

}).call(this);

//# sourceMappingURL=types.js.map