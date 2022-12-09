(function() {
  'use strict';
  var Decorators, Document, GUY, SQL, alert, debug, echo, get_base_types, get_document_types, help, info, inspect, isa, log, plain, praise, rpr, type_of, types, urge, warn, whisper;

  //###########################################################################################################
  GUY = require('guy');

  ({alert, debug, help, info, plain, praise, urge, warn, whisper} = GUY.trm.get_loggers('DATAMILL/SERVER'));

  ({rpr, inspect, echo, log} = GUY.trm);

  types = new (require('intertype')).Intertype();

  ({isa, type_of} = types);

  ({SQL} = (require('dbay')).DBay);

  //...........................................................................................................
  // FS                        = require 'node:fs'
  // PATH                      = require 'node:path'
  ({get_base_types, get_document_types} = require('./types'));

  //===========================================================================================================
  // DECORATORS
  //-----------------------------------------------------------------------------------------------------------
  Decorators = class Decorators {
    static get_all_first_values(table, field) {
      return function() {        /* TAINT use proper interpolation */
        return this.db.all_first_values(SQL`select ${field} from ${this.cfg.prefix}${table} order by 1;`);
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
        this.cfg = this.types.create.datamill_document_cfg(cfg);
        GUY.props.hide(this, 'db', this.cfg.db);
        delete this.cfg.db;
        this._procure_infrastructure();
        return void 0;
      }

      //---------------------------------------------------------------------------------------------------------
      _procure_infrastructure() {
        /* TAINT skip if tables found */
        var prefix;
        ({prefix} = this.cfg);
        this.db.set_foreign_keys_state(false);
        this.db(SQL`drop table if exists ${prefix}file;`);
        this.db.set_foreign_keys_state(true);
        //-------------------------------------------------------------------------------------------------------
        // TABLES
        //.......................................................................................................
        this.db(SQL`create table ${prefix}files (
    doc_file_id  text not null,
  primary key ( doc_file_id ) );`);
        //.......................................................................................................
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      new_external_file(cfg) {
        return cfg = this.types.create.new_external_file(cfg);
      }

    };

    //---------------------------------------------------------------------------------------------------------
    Document.prototype.get_doc_file_ids = Decorators.get_all_first_values('files', 'doc_file_id');

    return Document;

  }).call(this);

  //###########################################################################################################
  module.exports = {Document};

}).call(this);

//# sourceMappingURL=document.js.map