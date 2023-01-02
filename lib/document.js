(function() {
  'use strict';
  var Decorators, Document, FS, GUY, I, L, PATH, SQL, V, XE, alert, debug, echo, get_base_types, get_document_types, help, info, inspect, isa, log, plain, praise, rpr, sql, type_of, types, urge, warn, whisper,
    splice = [].splice;

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
        return this.db.all_first_values(SQL`select ${I(field)} from ${I(table)} order by 1;`);
      };
    }

    //---------------------------------------------------------------------------------------------------------
    static get_all_rows(table) {
      return function() {
        return this.db.all_rows(SQL`select * from ${I(table)} order by 1;`);
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
        this._procure_infrastructure();
        this._add_layout();
        this._listen_to_signals();
        return void 0;
      }

      //---------------------------------------------------------------------------------------------------------
      _procure_infrastructure() {
        var self;
        /* TAINT skip if tables found */
        // @db.set_foreign_keys_state false
        // @db SQL"""
        //   drop table if exists doc_file;"""
        // @db.set_foreign_keys_state true
        //-------------------------------------------------------------------------------------------------------
        this.db.create_function({
          name: 'abspath',
          deterministic: true,
          varargs: false,
          call: this.get_doc_src_abspath.bind(this)
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
          rows: function*(doc_src_abspath) {
            var doc_line_nr, doc_line_txt, doc_par_nr, is_blank, prv_was_blank, ref;
            doc_line_nr = 0;
            doc_par_nr = 0;
            prv_was_blank = true;
            ref = GUY.fs.walk_lines(doc_src_abspath);
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
        this.db(SQL`create table doc_sources (
    doc_src_id            text not null,
    doc_src_path         text not null,
    doc_src_hash         text,
    doc_src_abspath      text not null generated always as ( abspath( doc_src_path ) ) virtual,
    -- doc_fad_id            text not null references doc_fads,
    -- doc_src_parameters   json not null,
  primary key ( doc_src_id ) );`);
        //.......................................................................................................
        this.db(SQL`create view doc_live_raw_lines as select
    F.doc_src_id                as doc_src_id,
    L.doc_line_nr               as doc_line_nr,
    L.doc_par_nr                as doc_par_nr,
    L.doc_line_txt              as doc_line_txt
    -- is_blank( L.doc_line_txt )  as doc_line_is_blank
  from doc_sources                   as F,
  read_file_lines( F.doc_src_abspath ) as L
  order by F.doc_src_id, doc_line_nr;`);
        //.......................................................................................................
        this.db(SQL`create table doc_raw_lines (
    doc_src_id    text    not null references doc_sources on delete cascade,
    doc_line_nr   integer not null,
    doc_par_nr    integer not null,
    doc_line_txt  text    not null,
  primary key ( doc_src_id, doc_line_nr ) );`);
        //.......................................................................................................
        this.db(SQL`create table doc_locs (
    doc_src_id    text    not null references doc_sources on delete cascade,
    doc_loc_id    text    not null,
    doc_loc_kind  text    not null,
    doc_line_nr   integer not null /* references doc_raw_lines */,
    doc_loc_start integer not null,
    doc_loc_stop  integer not null,
    doc_loc_mark  integer not null,
  primary key ( doc_src_id, doc_loc_id, doc_loc_kind ),
  check ( doc_loc_kind in ( 'start', 'stop' ) ) );`);
        //.......................................................................................................
        this._insert_source_ps = this.db.prepare_insert({
          into: "doc_sources",
          returning: '*'
        });
        this._upsert_source_ps = this.db.prepare_insert({
          into: "doc_sources",
          returning: '*',
          on_conflict: {
            update: true
          }
        });
        this._delete_source_ps = this.db.prepare(SQL`delete from doc_sources where doc_src_id = $doc_src_id;`);
        this._insert_lines_2ps = this.db.alt.prepare(SQL`insert into doc_raw_lines
  select * from doc_live_raw_lines
    where doc_src_id = $doc_src_id;`);
        this._raw_lines_ps = this.db.prepare(SQL`select
    $doc_src_nr as doc_src_nr,
    *
  from doc_raw_lines
  where doc_src_id = $doc_src_id
  order by doc_line_nr;`);
        this._insert_loc_2ps = this.db.alt.prepare_insert({
          into: "doc_locs"
        });
        this._last_line_ps = this.db.prepare(SQL`select * from doc_raw_lines
  where true
    and doc_src_id = $doc_src_id
    and doc_line_nr = (
      select max( doc_line_nr )
        from doc_raw_lines
        where true
        and doc_src_id = $doc_src_id );`);
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      get_doc_src_abspath(doc_src_path) {
        return PATH.resolve(this.cfg.home, doc_src_path);
      }

      text_is_blank(text) {
        return text === '' || /^\s*$/.test(text);
      }

      // get_doc_fads:       Decorators.get_all_rows         'fads'

        //---------------------------------------------------------------------------------------------------------
      * walk_raw_lines(...region_ids) {
        /* TAINT reject unknown doc_src_id, doc_loc_id */
        var doc_loc_id, doc_src_id, doc_src_nr, i, idx, len, region_id;
        region_ids = region_ids.flat(2e308);
        for (idx = i = 0, len = region_ids.length; i < len; idx = ++i) {
          region_id = region_ids[idx];
          ({doc_src_id, doc_loc_id} = this._split_region_id(region_id));
          doc_src_nr = idx + 1;
          yield* this.db(this._raw_lines_ps, {doc_src_nr, doc_src_id});
        }
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      * walk_raw_lines_2(...region_ids) {
        /* TAINT reject unknown doc_src_id, doc_loc_id */
        var doc_loc_id, doc_src_id, doc_src_nr, first_line_nr, i, idx, last_line_nr, len, line, ref, region_id, start, stop;
        region_ids = region_ids.flat(2e308);
        for (idx = i = 0, len = region_ids.length; i < len; idx = ++i) {
          region_id = region_ids[idx];
          ({doc_src_id, doc_loc_id} = this._split_region_id(region_id));
          doc_src_nr = idx + 1;
          [start, stop] = this.db.all_rows(SQL`select * from doc_locs
where true
  and doc_src_id = $doc_src_id
  and doc_loc_id = $doc_loc_id
  order by doc_line_nr, doc_loc_start;`, {doc_src_id, doc_loc_id});
          first_line_nr = start.doc_line_nr;
          last_line_nr = stop.doc_line_nr;
          ref = this.db(SQL`select
    *
  from doc_raw_lines
  where true
    and doc_src_id = $doc_src_id
    and doc_line_nr between $first_line_nr and $last_line_nr
    order by doc_line_nr;`, {doc_src_id, first_line_nr, last_line_nr});
          for (line of ref) {
            /* truncate first and last lines */
            /* add indicator whether newlines are needed at ends */
            if ((line.doc_line_nr === first_line_nr) && (line.doc_line_nr === last_line_nr)) {
              line.doc_line_txt = line.doc_line_txt.slice(start.doc_loc_start, +stop.doc_loc_stop + 1 || 9e9);
            } else if (line.doc_line_nr === first_line_nr) {
              line.doc_line_txt = line.doc_line_txt.slice(start.doc_loc_start);
            } else if (line.doc_line_nr === last_line_nr) {
              line.doc_line_txt = line.doc_line_txt.slice(0, +stop.doc_loc_stop + 1 || 9e9);
            }
            line.doc_line_txt = this._loc_markers_as_html_comments(doc_src_id, line.doc_line_txt);
            yield line;
          }
        }
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
      add_source(cfg) {
        var doc_src_abspath, doc_src_hash, doc_src_id, doc_src_path, source;
        cfg = this.types.create.doc_add_source_cfg(cfg);
        ({doc_src_id, doc_src_path, doc_src_hash} = cfg);
        doc_src_abspath = this.get_doc_src_abspath(doc_src_path);
        if (doc_src_hash == null) {
          doc_src_hash = GUY.fs.get_content_hash(doc_src_abspath, {
            fallback: null
          });
        }
        source = this.db.first_row(this._insert_source_ps, {doc_src_id, doc_src_path, doc_src_hash});
        this.db.alt(this._insert_lines_2ps, {doc_src_id});
        /* TAINT only when licensed by extension `*.dm.*` or settings */
        this._add_locs_for_source(source);
        return source;
      }

      //---------------------------------------------------------------------------------------------------------
      _add_locs_for_source(source) {
        this.db.alt(() => {
          var loc, ref;
          ref = this._walk_locs_of_source(source);
          for (loc of ref) {
            this.db.alt(this._insert_loc_2ps, loc);
          }
          return null;
        });
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      _loc_markers_as_html_comments(doc_src_id, doc_line_txt) {
        doc_line_txt = doc_line_txt.replace(this.cfg._loc_marker_re, ($0, ..._) => {
          var doc_loc_id, groups, left_slash, ref, right_slash;
          ref = _, [..._] = ref, [groups] = splice.call(_, -1);
          ({left_slash, doc_loc_id, right_slash} = groups);
          if ((left_slash === '') && (right_slash === '')) {
            return `<!--(loc '${doc_loc_id}'-->`;
          } else if ((left_slash === '/') && (right_slash === '')) {
            return `<!--loc '${doc_loc_id}')-->`;
          } else if ((left_slash === '') && (right_slash === '/')) {
            return `<!--(loc '${doc_loc_id}')-->`;
          }
          return "<!--???-->";
        });
        return doc_line_txt;
      }

      //---------------------------------------------------------------------------------------------------------
      * _walk_locs_of_source(source) {
        var doc_line_nr, doc_loc_id, doc_loc_kind, doc_loc_mark, doc_loc_start, doc_loc_stop, doc_src_id, left_slash, length, line, match, ref, ref1, right_slash, stop, text;
        ({doc_src_id} = source);
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
            doc_loc_stop = doc_loc_start + length - 1;
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
              /* TAINT use custom error class, proper source location data */
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
      _delete_source(doc_src_id) {
        return this.db(this._delete_source_ps, {doc_src_id});
      }

      //---------------------------------------------------------------------------------------------------------
      update_source(cfg) {
        cfg = this.types.create.doc_update_file_cfg(cfg);
        return this.db.first_row(this._upsert_source_ps, cfg);
      }

      //---------------------------------------------------------------------------------------------------------
      _add_layout(cfg) {
        /* TAINT put path to layout into cfg */
        var doc_src_path;
        doc_src_path = PATH.resolve(__dirname, '../assets/layout.dm.html');
        return this.add_source({
          doc_src_id: 'layout',
          doc_src_path
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
        XE.listen_to('^maybe-source-changed', (d) => {
          /*
            * test whether source is registered
            * retrieve content hash
            * compare with registered content hash
            * if changed:
              * update DB content
              * `XE.emit '^source-changed', { doc_src_id, doc_src_path, }`
           */
          var doc_src_hash, source;
          source = this._file_from_abspath(d.doc_src_abspath);
          doc_src_hash = GUY.fs.get_content_hash(source.doc_src_abspath, {
            fallback: null
          });
          if (source.doc_src_hash !== doc_src_hash) {
            source.doc_src_hash = doc_src_hash;
            this.update_source(source);
            XE.emit('^source-changed', source);
          }
          return null;
        });
        return null;
      }

      //---------------------------------------------------------------------------------------------------------
      _file_from_abspath(doc_src_abspath) {
        return this.db.first_row(SQL`select * from doc_sources where doc_src_abspath = $doc_src_abspath`, {doc_src_abspath});
      }

    };

    //---------------------------------------------------------------------------------------------------------
    Document.prototype.get_doc_src_ids = Decorators.get_all_first_values('doc_sources', 'doc_src_id');

    return Document;

  }).call(this);

  //###########################################################################################################
  module.exports = {Document};

}).call(this);

//# sourceMappingURL=document.js.map