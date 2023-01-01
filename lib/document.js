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
        this._add_layout();
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
        this.db.create_function({
          name: 'abspath',
          deterministic: true,
          varargs: false,
          call: this.get_doc_file_abspath.bind(this)
        });
        //.......................................................................................................
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
        self = this;
        this.db.create_table_function({
          name: "read_file_lines",
          parameters: ['doc_src_id'],
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
        this.db(SQL`create table ${prefix}sources (
    doc_src_id            text not null,
    doc_file_path         text not null,
    doc_file_hash         text,
    doc_file_abspath      text not null generated always as ( abspath( doc_file_path ) ) virtual,
    -- doc_fad_id            text not null references ${prefix}fads,
    -- doc_file_parameters   json not null,
  primary key ( doc_src_id ) );`);
        //.......................................................................................................
        this.db(SQL`create view ${prefix}live_raw_lines as select
    F.doc_src_id                as doc_src_id,
    L.doc_line_nr               as doc_line_nr,
    L.doc_par_nr                as doc_par_nr,
    L.doc_line_txt              as doc_line_txt
    -- is_blank( L.doc_line_txt )  as doc_line_is_blank
  from ${prefix}sources                   as F,
  read_file_lines( F.doc_file_abspath ) as L
  order by F.doc_src_id, doc_line_nr;`);
        //.......................................................................................................
        this.db(SQL`create table ${prefix}raw_lines (
    doc_src_id    text    not null references ${prefix}sources on delete cascade,
    doc_line_nr   integer not null,
    doc_par_nr    integer not null,
    doc_line_txt  text    not null,
  primary key ( doc_src_id, doc_line_nr ) );`);
        //.......................................................................................................
        this.db(SQL`create table ${prefix}locs (
    doc_src_id    text    not null references ${prefix}sources on delete cascade,
    doc_loc_id    text    not null,
    doc_loc_kind  text    not null,
    doc_line_nr   integer not null /* references ${prefix}raw_lines */,
    doc_loc_start integer not null,
    doc_loc_stop  integer not null,
    doc_loc_mark  integer not null,
  primary key ( doc_src_id, doc_loc_id, doc_loc_kind ),
  check ( doc_loc_kind in ( 'start', 'stop' ) ) );`);
        //.......................................................................................................
        this._insert_file_ps = this.db.prepare_insert({
          into: `${prefix}sources`,
          returning: '*'
        });
        this._upsert_file_ps = this.db.prepare_insert({
          into: `${prefix}sources`,
          returning: '*',
          on_conflict: {
            update: true
          }
        });
        this._delete_file_ps = this.db.prepare(SQL`delete from ${prefix}sources where doc_src_id = $doc_src_id;`);
        this._insert_lines_2ps = this.db.alt.prepare(SQL`insert into ${prefix}raw_lines
  select * from ${prefix}live_raw_lines
    where doc_src_id = $doc_src_id;`);
        this._raw_lines_ps = this.db.prepare(SQL`select
    $doc_file_nr as doc_file_nr,
    *
  from ${prefix}raw_lines
  where doc_src_id = $doc_src_id
  order by doc_line_nr;`);
        this._insert_loc_2ps = this.db.alt.prepare_insert({
          into: `${prefix}locs`
        });
        this._last_line_ps = this.db.prepare(SQL`select * from ${prefix}raw_lines
  where true
    and doc_src_id = $doc_src_id
    and doc_line_nr = (
      select max( doc_line_nr )
        from ${prefix}raw_lines
        where true
        and doc_src_id = $doc_src_id );`);
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
      * walk_raw_lines(...region_ids) {
        /* TAINT reject unknown doc_src_id, doc_loc_id */
        var doc_file_nr, doc_loc_id, doc_src_id, i, idx, len, line, ref, region_id;
        region_ids = region_ids.flat(2e308);
        for (idx = i = 0, len = region_ids.length; i < len; idx = ++i) {
          region_id = region_ids[idx];
          ({doc_src_id, doc_loc_id} = this._split_region_id(region_id));
          doc_file_nr = idx + 1;
          ref = this.db(this._raw_lines_ps, {doc_file_nr, doc_src_id});
          for (line of ref) {
            yield line;
          }
        }
        // yield from @db @_raw_lines_ps, { doc_file_nr, doc_src_id, }
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      _split_region_id(region_id) {
        var match;
        this.types.validate.nonempty.text(region_id);
        match = region_id.match(/^(?<doc_src_id>[^#]+)#(?<doc_loc_id>.+)$/);
        if (match == null) {
          return {
            doc_src_id: region_id,
            doc_loc_id: '*'
          };
        }
        return match.groups;
      }

      //---------------------------------------------------------------------------------------------------------
      walk_loc_lines(cfg, ...P) {
        var doc_src_id, i, idx, len;
        if (P.length !== 0) {
          return this.walk_xxx_lines([...arguments]);
        }
        if (cfg == null) {
          cfg = [];
        }
        cfg = this.types.create.walk_xxx_lines_cfg(cfg);
        if (cfg.length === 0) {
          return [];
        }
        sql = [];
        ({L} = this.db.sql);
        for (idx = i = 0, len = cfg.length; i < len; idx = ++i) {
          doc_src_id = cfg[idx];
          sql.push(SQL`select ${L(idx + 1)} as doc_file_nr, * ` + SQL`from ${this.cfg.prefix}xxx_lines as R where R.doc_src_id = ${L(doc_src_id)}\n`);
        }
        return this.db(sql.join('union all\n'));
      }

      //---------------------------------------------------------------------------------------------------------
      add_file(cfg) {
        var doc_file_abspath, doc_file_hash, doc_file_path, doc_src_id, file;
        cfg = this.types.create.doc_add_file_cfg(cfg);
        ({doc_src_id, doc_file_path, doc_file_hash} = cfg);
        doc_file_abspath = this.get_doc_file_abspath(doc_file_path);
        if (doc_file_hash == null) {
          doc_file_hash = GUY.fs.get_content_hash(doc_file_abspath, {
            fallback: null
          });
        }
        file = this.db.first_row(this._insert_file_ps, {doc_src_id, doc_file_path, doc_file_hash});
        this.db.alt(this._insert_lines_2ps, {doc_src_id});
        /* TAINT only when licensed by extension `*.dm.*` or settings */
        this._add_locs_for_file(file);
        return file;
      }

      //---------------------------------------------------------------------------------------------------------
      _add_locs_for_file(file) {
        this.db.alt(() => {
          var loc, ref;
          ref = this._walk_locs_of_file(file);
          for (loc of ref) {
            this.db.alt(this._insert_loc_2ps, loc);
          }
          return null;
        });
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      * _walk_locs_of_file(file) {
        var doc_line_nr, doc_loc_id, doc_loc_kind, doc_loc_mark, doc_loc_start, doc_loc_stop, doc_src_id, left_slash, length, line, match, ref, ref1, right_slash, stop, text;
        ({doc_src_id} = file);
        //.......................................................................................................
        ({doc_line_nr, stop} = this._get_last_position_in_file(doc_src_id));
        yield ({
          doc_src_id,
          doc_line_nr: 1,
          doc_loc_id: '*',
          doc_loc_kind: 'start',
          doc_loc_start: 0,
          doc_loc_stop: 0,
          doc_loc_mark: 0
        });
        yield ({
          doc_src_id,
          doc_line_nr: doc_line_nr,
          doc_loc_id: '*',
          doc_loc_kind: 'stop',
          doc_loc_start: stop,
          doc_loc_stop: stop,
          doc_loc_mark: stop
        });
        ref = this.walk_raw_lines([doc_src_id]);
        //.......................................................................................................
        for (line of ref) {
          ({doc_line_nr} = line);
          ref1 = line.doc_line_txt.matchAll(this.cfg._loc_marker_re);
          for (match of ref1) {
            ({left_slash, doc_loc_id, right_slash} = match.groups);
            [text] = match;
            length = text.length;
            ({
              index: doc_loc_start
            } = match);
            doc_loc_stop = doc_loc_start + length;
            doc_loc_mark = null;
            doc_loc_kind = null;
            // debug '^57-1^', line.doc_src_id, line.doc_line_nr, { doc_loc_start, length, left_slash, right_slash, name, }
            if ((left_slash === '') && (right_slash === '')) {
              doc_loc_kind = 'start';
              doc_loc_mark = doc_loc_stop;
            } else if ((left_slash === '/') && (right_slash === '')) {
              doc_loc_kind = 'stop';
              doc_loc_mark = doc_loc_start;
            } else if ((left_slash === '') && (right_slash === '/')) {
              doc_loc_kind = 'start';
              doc_loc_mark = doc_loc_stop;
              yield ({doc_src_id, doc_line_nr, doc_loc_id, doc_loc_kind, doc_loc_start, doc_loc_stop, doc_loc_mark});
              doc_loc_kind = 'stop';
            } else {
              /* TAINT use custom error class, proper source file location data */
              throw new Error(`^datamill/document@1^ illegal location marker: ${rpr(text)}`);
            }
            yield ({doc_src_id, doc_line_nr, doc_loc_id, doc_loc_kind, doc_loc_start, doc_loc_stop, doc_loc_mark});
          }
        }
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      _get_last_position_in_file(doc_src_id) {
        var doc_line_nr, doc_line_txt;
        ({doc_line_nr, doc_line_txt} = this.db.first_row(this._last_line_ps, {doc_src_id}));
        return {
          doc_line_nr,
          stop: doc_line_txt.length
        };
      }

      //---------------------------------------------------------------------------------------------------------
      _delete_file(doc_src_id) {
        return this.db(this._delete_file_ps, {doc_src_id});
      }

      //---------------------------------------------------------------------------------------------------------
      update_file(cfg) {
        cfg = this.types.create.doc_update_file_cfg(cfg);
        return this.db.first_row(this._upsert_file_ps, cfg);
      }

      //---------------------------------------------------------------------------------------------------------
      _add_layout(cfg) {
        /* TAINT put path to layout into cfg */
        var doc_file_path;
        doc_file_path = PATH.resolve(__dirname, '../assets/layout.dm.html');
        return this.add_file({
          doc_src_id: 'layout',
          doc_file_path
        });
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
              * `XE.emit '^file-changed', { doc_src_id, doc_file_path, }`
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
        return this.db.first_row(SQL`select * from ${this.cfg.prefix}sources where doc_file_abspath = $doc_file_abspath`, {doc_file_abspath});
      }

    };

    //---------------------------------------------------------------------------------------------------------
    Document.prototype.get_doc_src_ids = Decorators.get_all_first_values('sources', 'doc_src_id');

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