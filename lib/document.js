(function() {
  'use strict';
  var Decorators, Document, FS, GUY, I, L, PATH, SQL, V, XE, alert, debug, echo, get_base_types, get_document_types, help, info, inspect, isa, log, plain, praise, rpr, sql, type_of, types, urge, warn, whisper;

  //###########################################################################################################
  GUY = require('guy');

  ({alert, debug, help, info, plain, praise, urge, warn, whisper} = GUY.trm.get_loggers('DATAMILL/DOCUMENT'));

  ({rpr, inspect, echo, log} = GUY.trm);

  types = new (require('intertype')).Intertype();

  ({isa, type_of} = types);

  ({SQL, sql} = require('dbay'));

  ({I, V, L} = sql);

  //...........................................................................................................
  FS = require('node:fs');

  PATH = require('node:path');

  ({get_base_types, get_document_types} = require('./types'));

  ({XE} = require('./_xemitter'));

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
        this._listen_to_signals();
        return void 0;
      }

      //---------------------------------------------------------------------------------------------------------
      _procure_infrastructure() {
        /* TAINT skip if tables found */
        var prefix, self;
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
        this.db.create_function({
          name: 'abspath',
          deterministic: true,
          varargs: false,
          call: this.get_doc_file_abspath.bind(this)
        });
        this.db.create_function({
          name: 'is_blank',
          deterministic: true,
          varargs: false,
          call: (text) => {
            if (this.text_is_blank(text)) {
              return 1;
            } else {
              return 0;
            }
          }
        });
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
        self = this;
        this.db.create_table_function({
          name: "read_file_lines",
          parameters: ['doc_file_id'],
          columns: ['doc_line_nr', 'doc_line_txt', 'doc_par_nr'],
          rows: function*(doc_file_abspath) {
            var doc_line_nr, doc_line_txt, doc_par_nr, is_blank, prv_was_blank, ref;
            doc_line_nr = 0;
            doc_par_nr = 0;
            prv_was_blank = true;
            ref = GUY.fs.walk_lines(doc_file_abspath);
            for (doc_line_txt of ref) {
              if ((!(is_blank = self.text_is_blank(doc_line_txt))) && prv_was_blank) {
                doc_par_nr++;
              }
              prv_was_blank = is_blank;
              doc_line_nr++;
              yield ({
                doc_line_nr,
                doc_par_nr: (is_blank ? 0 : doc_par_nr),
                doc_line_txt
              });
            }
            return null;
          }
        });
        //.......................................................................................................
        this.db(SQL`create view ${prefix}lines as select
    F.doc_file_id               as doc_file_id,
    L.doc_line_nr               as doc_line_nr,
    L.doc_par_nr                as doc_par_nr,
    L.doc_line_txt              as doc_line_txt
    -- is_blank( L.doc_line_txt )  as doc_line_is_blank
  from ${prefix}files                   as F,
  read_file_lines( F.doc_file_abspath ) as L
  order by 1, 2;`);
        //.......................................................................................................
        this._insert_file = this.db.prepare_insert({
          into: `${prefix}files`,
          returning: '*'
        });
        this._upsert_file = this.db.prepare_insert({
          into: `${prefix}files`,
          returning: '*',
          on_conflict: {
            update: true
          }
        });
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      get_doc_file_abspath(doc_file_path) {
        return PATH.resolve(this.cfg.home, doc_file_path);
      }

      text_is_blank(text) {
        return text === '' || /^\s*$/.test(text);
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

      //---------------------------------------------------------------------------------------------------------
      update_file(cfg) {
        cfg = this.types.create.doc_update_file_cfg(cfg);
        return this.db.first_row(this._upsert_file, cfg);
      }

      //=========================================================================================================
      // SIGNAL PROCESSING
      //---------------------------------------------------------------------------------------------------------
      _listen_to_signals() {
        // XE.listen_to          '^mykey',     ( d       ) ->  keys.listen   .push d.$key
        // XE.contract           '^otherkey',  ( d       ) ->  keys.contract .push d.$key; return "some value"
        //.......................................................................................................
        XE.listen_to_all(function(key, d) {
          return whisper('^23-1^', GUY.trm.reverse(`signal: ${rpr(d)}`));
        });
        XE.listen_to_unheard(function(key, d) {
          return warn(GUY.trm.reverse(`unheard signal: ${rpr(d)}`));
        });
        //.......................................................................................................
        XE.listen_to('^maybe-file-changed', (d) => {
          /*
            * test whether file is registered
            * retrieve content hash
            * compare with registered content hash
            * if changed:
              * update DB content
              * `XE.emit '^file-changed', { doc_file_id, doc_file_path, }`
           */
          var doc_file_hash, file;
          file = this._file_from_abspath(d.doc_file_abspath);
          doc_file_hash = GUY.fs.get_content_hash(file.doc_file_abspath, {
            fallback: null
          });
          if (file.doc_file_hash !== doc_file_hash) {
            file.doc_file_hash = doc_file_hash;
            this.update_file(file);
            XE.emit('^file-changed', file);
          }
          return null;
        });
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      _file_from_abspath(doc_file_abspath) {
        return this.db.first_row(SQL`select * from ${this.cfg.prefix}files where doc_file_abspath = $doc_file_abspath`, {doc_file_abspath});
      }

    };

    //---------------------------------------------------------------------------------------------------------
    Document.prototype.get_doc_file_ids = Decorators.get_all_first_values('files', 'doc_file_id');

    return Document;

  }).call(this);

  // #===========================================================================================================
  // # FILE ADAPTERS (FADs)
  // #===========================================================================================================
  // class File_adapter_abc
  //   @comment: "abstract base class for files"

  //   #---------------------------------------------------------------------------------------------------------
  //   constructor: ->
  //     GUY.props.hide @, 'types', get_document_types()
  //     return undefined

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

  // #===========================================================================================================
  // class External_text_file extends File_adapter_abc
  //   @comment: "adapter for external text files"

  //   #---------------------------------------------------------------------------------------------------------
  //   constructor: ( cfg ) ->
  //     super()
  //     debug '^354^', { cfg, }
  //     @cfg   = @types.create.new_external_text_file_cfg cfg
  //     return undefined

  //   #---------------------------------------------------------------------------------------------------------
  //   walk_lines: ->
  //     yield 'helo'
  //     yield 'world'
  //     return null

  //###########################################################################################################
  /* Abstract base classes use class name, instantiable classes short acronym with `x` meaning 'external',
  `txt` being most common file name extension for text files: */
  // file_adapters   =
  //   File_adapter_abc:   File_adapter_abc
  //   External_file_abc:  External_file_abc
  //   xtxt:               External_text_file
  // module.exports  = { Document, File_adapter_abc, file_adapters, }
  module.exports = {Document};

}).call(this);

//# sourceMappingURL=document.js.map