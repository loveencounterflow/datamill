
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
    @cfg        = @types.create.datamill_document_cfg cfg
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
    #.......................................................................................................
    @db SQL"""
      create table #{prefix}file_kinds (
          doc_file_kind           text not null,
          doc_file_kind_classname text not null,
          comment                 text,
        primary key ( doc_file_kind ) );"""
    #.......................................................................................................
    @db SQL"""
      create table #{prefix}files (
          doc_file_id         text not null,
          doc_file_kind       text not null references #{prefix}file_kinds,
          doc_file_parameters json not null,
        primary key ( doc_file_id ) );"""
    #.......................................................................................................
    insert_file_kind = @db.prepare_insert { into: "#{prefix}file_kinds", }
    @db =>
      for doc_file_kind, clasz of @file_adapters
        doc_file_kind_classname = clasz.name
        comment                 = clasz.comment ? null
        @db insert_file_kind, { doc_file_kind, doc_file_kind_classname, comment, }
    #.......................................................................................................
    return null

  #---------------------------------------------------------------------------------------------------------
  get_doc_file_ids:   Decorators.get_all_first_values 'files',      'doc_file_id'
  get_doc_file_kinds: Decorators.get_all_rows         'file_kinds'

  #---------------------------------------------------------------------------------------------------------
  new_file: ( cfg ) ->


#===========================================================================================================
class File_adapter_abc
  @comment: "abstract base class for files"


#===========================================================================================================
class External_file_abc extends File_adapter_abc
  @comment: "abstract base class for external files"


  #---------------------------------------------------------------------------------------------------------
  constructor: ( cfg ) ->
    super()
    @cfg   = @types.create.new_external_file_cfg cfg
    return undefined

  #---------------------------------------------------------------------------------------------------------
  write:        null
  walk_chunks:  null
  walk_lines:   null

#===========================================================================================================
class External_text_file extends External_file_abc
  @comment: "adapter for external text files"

  #---------------------------------------------------------------------------------------------------------
  constructor: ( cfg ) ->
    super()
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
  File_adapter_abc:   File_adapter_abc
  External_file_abc:  External_file_abc
  xtxt:               External_text_file
module.exports  = { Document, File_adapter_abc, file_adapters, }





