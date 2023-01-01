
'use strict'


############################################################################################################
GUY                       = require 'guy'
{ alert
  debug
  help
  info
  plain
  praise
  urge
  warn
  whisper }               = GUY.trm.get_loggers 'DATAMILL/DOCUMENT'
{ rpr
  inspect
  echo
  log     }               = GUY.trm
types                     = new ( require 'intertype' ).Intertype()
{ isa
  type_of }               = types
{ SQL 
  sql }                   = require 'dbay'
{ I, V, L, }              = sql
#...........................................................................................................
FS                        = require 'node:fs'
PATH                      = require 'node:path'
{ get_base_types
  get_document_types }    = require './types'
{ XE }                    = require './_xemitter'


#===========================================================================================================
# DECORATORS
#-----------------------------------------------------------------------------------------------------------
class Decorators
  
  ### NOTE this could meaningfully go into a static DBay submodule to assist in building client APIs ###

  #---------------------------------------------------------------------------------------------------------
  @get_all_first_values: ( table, field ) ->
    -> @db.all_first_values SQL"select #{I field} from #{I @cfg.prefix+table} order by 1;"

  #---------------------------------------------------------------------------------------------------------
  @get_all_rows: ( table ) ->
    -> @db.all_rows SQL"select * from #{I @cfg.prefix+table} order by 1;"

#===========================================================================================================
class Document

  #=========================================================================================================
  # CONSTRUCTION
  #---------------------------------------------------------------------------------------------------------
  constructor: ( cfg ) ->
    # super()
    GUY.props.hide @, 'types', get_document_types()
    @cfg        = @types.create.doc_document_cfg cfg
    GUY.props.hide @, 'db',             @cfg.db;            delete @cfg.db
    GUY.props.hide @, 'file_adapters',  @cfg.file_adapters; delete @cfg.file_adapters
    @_procure_infrastructure()
    @_add_layout()
    @_listen_to_signals()
    return undefined

  #---------------------------------------------------------------------------------------------------------
  _procure_infrastructure: ->
    ### TAINT skip if tables found ###
    { prefix } = @cfg
    @db.set_foreign_keys_state false
    @db SQL"""
      drop table if exists #{prefix}file;"""
    @db.set_foreign_keys_state true
    #-------------------------------------------------------------------------------------------------------
    @db.create_function
      name:           'abspath'
      deterministic:  true
      varargs:        false
      call:           @get_doc_src_abspath.bind @
    #.......................................................................................................
    @db.create_function
      name:           'is_blank'
      deterministic:  true
      varargs:        false
      call:           ( text ) => if ( @text_is_blank text ) then 1 else 0
    #.......................................................................................................
    self = @
    @db.create_table_function
      name:         "read_file_lines"
      parameters:   [ 'doc_src_id', ]
      columns:      [ 'doc_line_nr', 'doc_line_txt', 'doc_par_nr', ]
      rows:         ( doc_src_abspath ) ->
        doc_line_nr   = 0
        doc_par_nr    = 0
        prv_was_blank = true
        for doc_line_txt from GUY.fs.walk_lines doc_src_abspath
          doc_par_nr++ if ( not ( is_blank = self.text_is_blank doc_line_txt ) ) and prv_was_blank
          prv_was_blank = is_blank
          doc_line_nr++
          yield { doc_line_nr, doc_par_nr: ( if is_blank then 0 else doc_par_nr ), doc_line_txt, }
        return null
    #.......................................................................................................
    @db SQL"""
      create table #{prefix}sources (
          doc_src_id            text not null,
          doc_src_path         text not null,
          doc_src_hash         text,
          doc_src_abspath      text not null generated always as ( abspath( doc_src_path ) ) virtual,
          -- doc_fad_id            text not null references #{prefix}fads,
          -- doc_src_parameters   json not null,
        primary key ( doc_src_id ) );"""
    #.......................................................................................................
    @db SQL"""
      create view #{prefix}live_raw_lines as select
          F.doc_src_id                as doc_src_id,
          L.doc_line_nr               as doc_line_nr,
          L.doc_par_nr                as doc_par_nr,
          L.doc_line_txt              as doc_line_txt
          -- is_blank( L.doc_line_txt )  as doc_line_is_blank
        from #{prefix}sources                   as F,
        read_file_lines( F.doc_src_abspath ) as L
        order by F.doc_src_id, doc_line_nr;"""
    #.......................................................................................................
    @db SQL"""
      create table #{prefix}raw_lines (
          doc_src_id    text    not null references #{prefix}sources on delete cascade,
          doc_line_nr   integer not null,
          doc_par_nr    integer not null,
          doc_line_txt  text    not null,
        primary key ( doc_src_id, doc_line_nr ) );"""
    #.......................................................................................................
    @db SQL"""
      create table #{prefix}locs (
          doc_src_id    text    not null references #{prefix}sources on delete cascade,
          doc_loc_id    text    not null,
          doc_loc_kind  text    not null,
          doc_line_nr   integer not null /* references #{prefix}raw_lines */,
          doc_loc_start integer not null,
          doc_loc_stop  integer not null,
          doc_loc_mark  integer not null,
        primary key ( doc_src_id, doc_loc_id, doc_loc_kind ),
        check ( doc_loc_kind in ( 'start', 'stop' ) ) );"""
    #.......................................................................................................
    @_insert_file_ps    = @db.prepare_insert { into: "#{prefix}sources", returning: '*', }
    @_upsert_file_ps    = @db.prepare_insert { into: "#{prefix}sources", returning: '*', on_conflict: { update: true, }, }
    @_delete_file_ps    = @db.prepare SQL"""delete from #{prefix}sources where doc_src_id = $doc_src_id;"""
    @_insert_lines_2ps  = @db.alt.prepare SQL"""
      insert into #{prefix}raw_lines
        select * from #{prefix}live_raw_lines
          where doc_src_id = $doc_src_id;"""
    @_raw_lines_ps      = @db.prepare SQL"""
      select
          $doc_src_nr as doc_src_nr,
          *
        from #{prefix}raw_lines
        where doc_src_id = $doc_src_id
        order by doc_line_nr;"""
    @_insert_loc_2ps    = @db.alt.prepare_insert { into: "#{prefix}locs", }
    @_last_line_ps      = @db.prepare SQL"""
      select * from #{prefix}raw_lines
        where true
          and doc_src_id = $doc_src_id
          and doc_line_nr = (
            select max( doc_line_nr )
              from #{prefix}raw_lines
              where true
              and doc_src_id = $doc_src_id );"""
    return null

  #---------------------------------------------------------------------------------------------------------
  get_doc_src_abspath:  ( doc_src_path  ) -> PATH.resolve @cfg.home, doc_src_path
  text_is_blank:        ( text          ) -> text is '' or /^\s*$/.test text

  #---------------------------------------------------------------------------------------------------------
  get_doc_src_ids:   Decorators.get_all_first_values 'sources',      'doc_src_id'
  # get_doc_fads:       Decorators.get_all_rows         'fads'

  #---------------------------------------------------------------------------------------------------------
  walk_raw_lines: ( region_ids... ) ->
    region_ids = region_ids.flat Infinity
    for region_id, idx in region_ids
      { doc_src_id
        doc_loc_id } = @_split_region_id region_id
      ### TAINT reject unknown doc_src_id, doc_loc_id ###
      doc_src_nr = idx + 1
      for line from @db @_raw_lines_ps, { doc_src_nr, doc_src_id, }
        yield line
      # yield from @db @_raw_lines_ps, { doc_src_nr, doc_src_id, }
    return null

  #---------------------------------------------------------------------------------------------------------
  _split_region_id: ( region_id ) ->
    @types.validate.nonempty.text region_id
    match = region_id.match /^(?<doc_src_id>[^#]+)#(?<doc_loc_id>.+)$/
    return { doc_src_id: region_id, doc_loc_id: '*', } unless match?
    return match.groups

  #---------------------------------------------------------------------------------------------------------
  walk_loc_lines: ( cfg, P... ) ->
    return @walk_xxx_lines [ arguments..., ] if ( P.length isnt 0 )
    cfg  ?= []
    cfg   = @types.create.walk_xxx_lines_cfg cfg
    return [] if cfg.length is 0
    sql   = []
    { L } = @db.sql
    for doc_src_id, idx in cfg
      sql.push \
        SQL"select #{L idx + 1} as doc_src_nr, * " + \
          SQL"from #{@cfg.prefix}xxx_lines as R where R.doc_src_id = #{L doc_src_id}\n"
    return @db sql.join 'union all\n'

  #---------------------------------------------------------------------------------------------------------
  add_file: ( cfg ) ->
    cfg = @types.create.doc_add_file_cfg cfg
    { doc_src_id
      doc_src_path
      doc_src_hash } = cfg
    doc_src_abspath  = @get_doc_src_abspath doc_src_path
    doc_src_hash    ?= GUY.fs.get_content_hash doc_src_abspath, { fallback: null, }
    file              = @db.first_row @_insert_file_ps, { doc_src_id, doc_src_path, doc_src_hash, }
    @db.alt @_insert_lines_2ps, { doc_src_id, }
    ### TAINT only when licensed by extension `*.dm.*` or settings ###
    @_add_locs_for_file file
    return file

  #---------------------------------------------------------------------------------------------------------
  _add_locs_for_file: ( file ) ->
    @db.alt =>
      for loc from @_walk_locs_of_file file
        @db.alt @_insert_loc_2ps, loc
      return null
    return null

  #---------------------------------------------------------------------------------------------------------
  _walk_locs_of_file: ( file ) ->
    { doc_src_id, }  = file
    #.......................................................................................................
    { doc_line_nr
      stop        } = @_get_last_position_in_file doc_src_id
    yield {
      doc_src_id, doc_line_nr: 1, doc_loc_id: '*', doc_loc_kind: 'start',
      doc_loc_start: 0, doc_loc_stop: 0, doc_loc_mark: 0, }
    yield {
      doc_src_id, doc_line_nr: doc_line_nr, doc_loc_id: '*', doc_loc_kind: 'stop',
      doc_loc_start: stop, doc_loc_stop: stop, doc_loc_mark: stop, }
    #.......................................................................................................
    for line from @walk_raw_lines [ doc_src_id, ]
      { doc_line_nr } = line
      for match from line.doc_line_txt.matchAll @cfg._loc_marker_re
        { left_slash
          doc_loc_id
          right_slash           } = match.groups
        [ text ]                  = match
        length                    = text.length
        { index: doc_loc_start, } = match
        doc_loc_stop              = doc_loc_start + length
        doc_loc_mark              = null
        doc_loc_kind              = null
        # debug '^57-1^', line.doc_src_id, line.doc_line_nr, { doc_loc_start, length, left_slash, right_slash, name, }
        if ( left_slash is '' ) and ( right_slash is '' )
          doc_loc_kind  = 'start'
          doc_loc_mark  = doc_loc_stop
        else if ( left_slash is '/' ) and ( right_slash is '' )
          doc_loc_kind  = 'stop'
          doc_loc_mark  = doc_loc_start
        else if ( left_slash is '' ) and ( right_slash is '/' )
          doc_loc_kind  = 'start'
          doc_loc_mark  = doc_loc_stop
          yield {
            doc_src_id, doc_line_nr, doc_loc_id, doc_loc_kind,
            doc_loc_start, doc_loc_stop, doc_loc_mark, }
          doc_loc_kind  = 'stop'
        else
          ### TAINT use custom error class, proper source file location data ###
          throw new Error "^datamill/document@1^ illegal location marker: #{rpr text}"
        yield {
          doc_src_id, doc_line_nr, doc_loc_id, doc_loc_kind,
          doc_loc_start, doc_loc_stop, doc_loc_mark, }
    return null

  #---------------------------------------------------------------------------------------------------------
  _get_last_position_in_file: ( doc_src_id ) ->
    { doc_line_nr
      doc_line_txt  } = @db.first_row @_last_line_ps, { doc_src_id, }
    return { doc_line_nr, stop: doc_line_txt.length, }

  #---------------------------------------------------------------------------------------------------------
  _delete_file: ( doc_src_id ) -> @db @_delete_file_ps, { doc_src_id, }

  #---------------------------------------------------------------------------------------------------------
  update_file: ( cfg ) ->
    cfg = @types.create.doc_update_file_cfg cfg
    return @db.first_row @_upsert_file_ps, cfg

  #---------------------------------------------------------------------------------------------------------
  _add_layout: ( cfg ) ->
    ### TAINT put path to layout into cfg ###
    doc_src_path = PATH.resolve __dirname, '../assets/layout.dm.html'
    @add_file { doc_src_id: 'layout', doc_src_path, }


  #=========================================================================================================
  # SIGNAL PROCESSING
  #---------------------------------------------------------------------------------------------------------
  _listen_to_signals: ->
    # XE.listen_to          '^mykey',     ( d       ) ->  keys.listen   .push d.$key
    # XE.contract           '^otherkey',  ( d       ) ->  keys.contract .push d.$key; return "some value"
    #.......................................................................................................
    XE.listen_to_all ( key, d ) -> whisper '^23-1^', GUY.trm.reverse "signal: #{rpr d}"
    XE.listen_to_unheard ( key, d ) -> warn GUY.trm.reverse "unheard signal: #{rpr d}"
    #.......................................................................................................
    XE.listen_to '^maybe-file-changed', ( d ) =>
      ###
        * test whether file is registered
        * retrieve content hash
        * compare with registered content hash
        * if changed:
          * update DB content
          * `XE.emit '^file-changed', { doc_src_id, doc_src_path, }`
      ###
      file            = @_file_from_abspath d.doc_src_abspath
      doc_src_hash   = GUY.fs.get_content_hash file.doc_src_abspath, { fallback: null, }
      if file.doc_src_hash isnt doc_src_hash
        file.doc_src_hash = doc_src_hash
        @update_file file
        XE.emit '^file-changed', file
      return null
    return null

  #---------------------------------------------------------------------------------------------------------
  _file_from_abspath: ( doc_src_abspath ) -> @db.first_row SQL"
    select * from #{@cfg.prefix}sources where doc_src_abspath = $doc_src_abspath", { doc_src_abspath, }


# #===========================================================================================================
# # FILE ADAPTERS (FADs)
# #===========================================================================================================
# class File_adapter_abc
#   @comment: "abstract base class for files"

#   #---------------------------------------------------------------------------------------------------------
#   constructor: ->
#     GUY.props.hide @, 'types', get_document_types()
#     return undefined


# #===========================================================================================================
# class External_file_abc extends File_adapter_abc
#   @comment: "abstract base class for external files"

#   #---------------------------------------------------------------------------------------------------------
#   constructor: ( cfg ) ->
#     super cfg
#     @cfg   = @types.create.new_external_file_cfg cfg
#     return undefined

#   #---------------------------------------------------------------------------------------------------------
#   write:        null
#   walk_chunks:  null
#   walk_lines:   null

# #===========================================================================================================
# class External_text_file extends File_adapter_abc
#   @comment: "adapter for external text files"

#   #---------------------------------------------------------------------------------------------------------
#   constructor: ( cfg ) ->
#     super()
#     debug '^354^', { cfg, }
#     @cfg   = @types.create.new_external_text_file_cfg cfg
#     return undefined

#   #---------------------------------------------------------------------------------------------------------
#   walk_lines: ->
#     yield 'helo'
#     yield 'world'
#     return null


############################################################################################################
### Abstract base classes use class name, instantiable classes short acronym with `x` meaning 'external',
`txt` being most common file name extension for text files: ###
# file_adapters   =
#   File_adapter_abc:   File_adapter_abc
#   External_file_abc:  External_file_abc
#   xtxt:               External_text_file
# module.exports  = { Document, File_adapter_abc, file_adapters, }
module.exports  = { Document, }





