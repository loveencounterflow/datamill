
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
# FS                        = require 'node:fs'
# PATH                      = require 'node:path'
{ get_base_types
  get_document_types }      = require './types'


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
    # TABLES
    # #.......................................................................................................
    # @db SQL"""
    #   create table #{prefix}fads (
    #       doc_fad_id            text not null,
    #       doc_fad_name          text not null,
    #       comment               text,
    #     primary key ( doc_fad_id ) );"""
    #.......................................................................................................
    FS    = require 'node:fs'
    PATH  = require 'node:path'
    abspath_cfg =
      name:           'abspath'
      deterministic:  true
      varargs:        false
      ### TAINT path should be relative to document location, not relative to this module ###
      call:           ( path ) -> PATH.join __dirname, '..', path
    @db.create_function abspath_cfg
    @db.alt.create_function abspath_cfg
    #.......................................................................................................
    @db SQL"""
      create table #{prefix}files (
          doc_file_id           text not null,
          doc_file_path         text not null,
          -- doc_file_hash         text not null,
          doc_file_abspath      text not null generated always as ( abspath( doc_file_path ) ) virtual,
          -- doc_fad_id            text not null references #{prefix}fads,
          -- doc_file_parameters   json not null,
        primary key ( doc_file_id ) );"""
    # #.......................................................................................................
    # @db SQL"""
    #   create table #{prefix}lines (
    #       doc_file_id           text    not null references #{prefix}files,
    #       doc_line_nr           integer not null,
    #       doc_line_text         text    not null,
    #       -- doc_fad_id            text not null references #{prefix}fads,
    #       -- doc_file_parameters   json not null,
    #     primary key ( doc_file_id, doc_line_nr ) );"""
    #.......................................................................................................
    _lines_of = ( doc_file_id ) ->
      doc_file_abspath = @db.alt.single_value SQL"""
        select doc_file_abspath from #{prefix}files where doc_file_id = $doc_file_id;""", { doc_file_id, }
      lines = ( FS.readFileSync doc_file_abspath, { encoding: 'utf-8', } ).split '\n'
      for line, line_idx in lines
        yield { path, lnr: line_idx + 1, line, }
      return null
    @db.create_table_function
      name:         "_lines_of"
      parameters:   [ 'doc_file_id', ]
      columns:      [ 'path', 'lnr', 'line', ]
      rows:         _lines_of.bind @
    #.......................................................................................................
    # path          = PATH.resolve PATH.join __dirname, '../../hengist/assets/icql', 'ncrglyphwbf.tsv'
    # info '^3453^', @db.prepare_insert { into: "#{prefix}files", exclude: [ 'doc_file_abspath', ], returning: '*', }
    path              = '../hengist/assets/icql/ncrglyphwbf.tsv'
    @_insert_file     = @db.prepare_insert { into: "#{prefix}files", exclude: [ 'doc_file_abspath', ], returning: '*', }
    debug '^3223847^', @db.first_row @_insert_file, { doc_file_id: 'f1', doc_file_path: path, }
    result  = @db.all_rows SQL"""
      select
          *
        from #{prefix}files as f,
        _lines_of( f.doc_file_id );""" # where lnr between 10 and 14 order by 1, 2, 3;"
    console.table result
    # for row from @db SQL"""select * from @"""
    #.......................................................................................................
    # insert_file_kind = @db.prepare_insert { into: "#{prefix}fads", }
    # @db =>
    #   for doc_fad_id, clasz of @file_adapters
    #     doc_fad_name  = clasz.name
    #     comment       = clasz.comment ? null
    #     @db insert_file_kind, { doc_fad_id, doc_fad_name, comment, }
    #.......................................................................................................
    return null

  #---------------------------------------------------------------------------------------------------------
  get_doc_file_ids:   Decorators.get_all_first_values 'files',      'doc_file_id'
  # get_doc_fads:       Decorators.get_all_rows         'fads'

  #---------------------------------------------------------------------------------------------------------
  add_file: ( cfg ) ->
    cfg = @types.create.doc_add_file_cfg cfg
    debug '^24624^', cfg
    debug '^24624^', @file_adapters
    debug '^24624^', clasz = @file_adapters[ cfg.doc_fad_id ]
    R = new clasz cfg
    return R


#===========================================================================================================
# FILE ADAPTERS (FADs)
#===========================================================================================================
class File_adapter_abc
  @comment: "abstract base class for files"

  #---------------------------------------------------------------------------------------------------------
  constructor: ->
    GUY.props.hide @, 'types', get_document_types()
    return undefined


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

#===========================================================================================================
class External_text_file extends File_adapter_abc
  @comment: "adapter for external text files"

  #---------------------------------------------------------------------------------------------------------
  constructor: ( cfg ) ->
    super()
    debug '^354^', { cfg, }
    @cfg   = @types.create.new_external_text_file_cfg cfg
    return undefined

  #---------------------------------------------------------------------------------------------------------
  walk_lines: ->
    yield 'helo'
    yield 'world'
    return null


############################################################################################################
### Abstract base classes use class name, instantiable classes short acronym with `x` meaning 'external',
`txt` being most common file name extension for text files: ###
file_adapters   =
  # File_adapter_abc:   File_adapter_abc
  # External_file_abc:  External_file_abc
  xtxt:               External_text_file
module.exports  = { Document, File_adapter_abc, file_adapters, }





