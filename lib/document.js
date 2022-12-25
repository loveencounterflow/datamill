(function() {
  'use strict';
  var Decorators, Document, External_text_file, File_adapter_abc, GUY, I, L, PATH, SQL, V, alert, debug, echo, file_adapters, get_base_types, get_document_types, help, info, inspect, isa, log, plain, praise, rpr, sql, type_of, types, urge, warn, whisper;

  //###########################################################################################################
  GUY = require('guy');

  ({alert, debug, help, info, plain, praise, urge, warn, whisper} = GUY.trm.get_loggers('DATAMILL/DOCUMENT'));

  ({rpr, inspect, echo, log} = GUY.trm);

  types = new (require('intertype')).Intertype();

  ({isa, type_of} = types);

  ({SQL, sql} = require('dbay'));

  ({I, V, L} = sql);

  //...........................................................................................................
  // FS                        = require 'node:fs'
  PATH = require('node:path');

  ({get_base_types, get_document_types} = require('./types'));

  //===========================================================================================================
  // DECORATORS
  //-----------------------------------------------------------------------------------------------------------
  Decorators = class Decorators {
    /* NOTE this could meaningfully go into a static DBay submodule to assist in building client APIs */
    //---------------------------------------------------------------------------------------------------------
    static get_all_first_values(table, field) {
      return function() {
        return this.db.all_first_values(SQL`select ${I(field)} from ${I(this.cfg.prefix + table)} order by 1;`);
      };
    }

    //---------------------------------------------------------------------------------------------------------
    static get_all_rows(table) {
      return function() {
        return this.db.all_rows(SQL`select * from ${I(this.cfg.prefix + table)} order by 1;`);
      };
    }

  };

  Document = (function() {
    //===========================================================================================================
    class Document {
      //=========================================================================================================
      // CONSTRUCTION
      //---------------------------------------------------------------------------------------------------------
      constructor(cfg) {
        // super()
        GUY.props.hide(this, 'types', get_document_types());
        this.cfg = this.types.create.doc_document_cfg(cfg);
        GUY.props.hide(this, 'db', this.cfg.db);
        delete this.cfg.db;
        GUY.props.hide(this, 'file_adapters', this.cfg.file_adapters);
        delete this.cfg.file_adapters;
        this._procure_infrastructure();
        return void 0;
      }

      //---------------------------------------------------------------------------------------------------------
      _procure_infrastructure() {
        /* TAINT skip if tables found */
        var FS, abspath_cfg, prefix;
        ({prefix} = this.cfg);
        this.db.set_foreign_keys_state(false);
        this.db(SQL`drop table if exists ${prefix}file;`);
        this.db.set_foreign_keys_state(true);
        //-------------------------------------------------------------------------------------------------------
        // TABLES
        // #.......................................................................................................
        // @db SQL"""
        //   create table #{prefix}fads (
        //       doc_fad_id            text not null,
        //       doc_fad_name          text not null,
        //       comment               text,
        //     primary key ( doc_fad_id ) );"""
        //.......................................................................................................
        FS = require('node:fs');
        PATH = require('node:path');
        abspath_cfg = {
          name: 'abspath',
          deterministic: true,
          varargs: false,
          call: this.get_doc_file_abspath.bind(this)
        };
        this.db.create_function(abspath_cfg);
        this.db.alt.create_function(abspath_cfg);
        //.......................................................................................................
        this.db(SQL`create table ${prefix}files (
    doc_file_id           text not null,
    doc_file_path         text not null,
    doc_file_hash         text,
    doc_file_abspath      text not null generated always as ( abspath( doc_file_path ) ) virtual,
    -- doc_fad_id            text not null references ${prefix}fads,
    -- doc_file_parameters   json not null,
  primary key ( doc_file_id ) );`);
        //.......................................................................................................
        this.db.create_table_function({
          name: "lines_of",
          parameters: ['doc_file_id'],
          columns: ['doc_line_nr', 'doc_line_txt'],
          rows: function*(doc_file_abspath) {
            var doc_line_nr, doc_line_txt, ref;
            doc_line_nr = 0;
            ref = GUY.fs.walk_lines(doc_file_abspath);
            for (doc_line_txt of ref) {
              doc_line_nr++;
              yield ({doc_line_nr, doc_line_txt});
            }
            return null;
          }
        });
        //.......................................................................................................
        this.db(SQL`create view ${prefix}lines as select
    f.doc_file_id,
    l.doc_line_nr,
    l.doc_line_txt
  from ${prefix}files             as f,
  lines_of( f.doc_file_abspath )  as l
  order by 1, 2;`);
        //.......................................................................................................
        this._insert_file = this.db.prepare_insert({
          into: `${prefix}files`,
          returning: '*'
        });
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      get_doc_file_abspath(doc_file_path) {
        return PATH.resolve(this.cfg.home, doc_file_path);
      }

      // get_doc_fads:       Decorators.get_all_rows         'fads'

        //---------------------------------------------------------------------------------------------------------
      add_file(cfg) {
        var doc_file_abspath, doc_file_hash, doc_file_id, doc_file_path;
        cfg = this.types.create.doc_add_file_cfg(cfg);
        ({doc_file_id, doc_file_path, doc_file_hash} = cfg);
        doc_file_abspath = this.get_doc_file_abspath(doc_file_path);
        if (doc_file_hash == null) {
          doc_file_hash = GUY.fs.get_content_hash(doc_file_abspath, {
            fallback: null
          });
        }
        return this.db.first_row(this._insert_file, {doc_file_id, doc_file_path, doc_file_hash});
      }

    };

    //---------------------------------------------------------------------------------------------------------
    Document.prototype.get_doc_file_ids = Decorators.get_all_first_values('files', 'doc_file_id');

    return Document;

  }).call(this);

  File_adapter_abc = (function() {
    //===========================================================================================================
    // FILE ADAPTERS (FADs)
    //===========================================================================================================
    class File_adapter_abc {
      //---------------------------------------------------------------------------------------------------------
      constructor() {
        GUY.props.hide(this, 'types', get_document_types());
        return void 0;
      }

    };

    File_adapter_abc.comment = "abstract base class for files";

    return File_adapter_abc;

  }).call(this);

  External_text_file = (function() {
    // #===========================================================================================================
    // class External_file_abc extends File_adapter_abc
    //   @comment: "abstract base class for external files"

      //   #---------------------------------------------------------------------------------------------------------
    //   constructor: ( cfg ) ->
    //     super cfg
    //     @cfg   = @types.create.new_external_file_cfg cfg
    //     return undefined

      //   #---------------------------------------------------------------------------------------------------------
    //   write:        null
    //   walk_chunks:  null
    //   walk_lines:   null

      //===========================================================================================================
    class External_text_file extends File_adapter_abc {
      //---------------------------------------------------------------------------------------------------------
      constructor(cfg) {
        super();
        debug('^354^', {cfg});
        this.cfg = this.types.create.new_external_text_file_cfg(cfg);
        return void 0;
      }

      //---------------------------------------------------------------------------------------------------------
      * walk_lines() {
        yield 'helo';
        yield 'world';
        return null;
      }

    };

    External_text_file.comment = "adapter for external text files";

    return External_text_file;

  }).call(this);

  //###########################################################################################################
  /* Abstract base classes use class name, instantiable classes short acronym with `x` meaning 'external',
  `txt` being most common file name extension for text files: */
  file_adapters = {
    // File_adapter_abc:   File_adapter_abc
    // External_file_abc:  External_file_abc
    xtxt: External_text_file
  };

  module.exports = {Document, File_adapter_abc, file_adapters};

}).call(this);

//# sourceMappingURL=document.js.map