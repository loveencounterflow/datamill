(function() {
  'use strict';
  var Decorators, Document, External_text_file, File_adapter_abc, GUY, I, L, SQL, V, alert, debug, echo, file_adapters, get_base_types, get_document_types, help, info, inspect, isa, log, plain, praise, rpr, sql, type_of, types, urge, warn, whisper;

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
  // PATH                      = require 'node:path'
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
        var insert_file_kind, prefix;
        ({prefix} = this.cfg);
        this.db.set_foreign_keys_state(false);
        this.db(SQL`drop table if exists ${prefix}file;`);
        this.db.set_foreign_keys_state(true);
        //-------------------------------------------------------------------------------------------------------
        // TABLES
        //.......................................................................................................
        this.db(SQL`create table ${prefix}fads (
    doc_fad_id            text not null,
    doc_fad_name          text not null,
    comment               text,
  primary key ( doc_fad_id ) );`);
        //.......................................................................................................
        this.db(SQL`create table ${prefix}files (
    doc_file_id           text not null,
    doc_fad_id            text not null references ${prefix}fads,
    doc_file_parameters   json not null,
  primary key ( doc_file_id ) );`);
        //.......................................................................................................
        insert_file_kind = this.db.prepare_insert({
          into: `${prefix}fads`
        });
        this.db(() => {
          var clasz, comment, doc_fad_id, doc_fad_name, ref, ref1, results;
          ref = this.file_adapters;
          results = [];
          for (doc_fad_id in ref) {
            clasz = ref[doc_fad_id];
            doc_fad_name = clasz.name;
            comment = (ref1 = clasz.comment) != null ? ref1 : null;
            results.push(this.db(insert_file_kind, {doc_fad_id, doc_fad_name, comment}));
          }
          return results;
        });
        //.......................................................................................................
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      add_file(cfg) {
        var R, clasz;
        cfg = this.types.create.doc_add_file_cfg(cfg);
        debug('^24624^', cfg);
        debug('^24624^', this.file_adapters);
        debug('^24624^', clasz = this.file_adapters[cfg.doc_fad_id]);
        R = new clasz(cfg);
        return R;
      }

    };

    //---------------------------------------------------------------------------------------------------------
    Document.prototype.get_doc_file_ids = Decorators.get_all_first_values('files', 'doc_file_id');

    Document.prototype.get_doc_fads = Decorators.get_all_rows('fads');

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