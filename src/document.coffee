
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
    @db.create_function
      name:           'abspath'
      deterministic:  true
      varargs:        false
      call:           @get_doc_file_abspath.bind @
    @db.create_function
      name:           'is_blank'
      deterministic:  true
      varargs:        false
      call:           ( text ) => if ( @text_is_blank text ) then 1 else 0
    #.......................................................................................................
    @db SQL"""
      create table #{prefix}files (
          doc_file_id           text not null,
          doc_file_path         text not null,
          doc_file_hash         text,
          doc_file_abspath      text not null generated always as ( abspath( doc_file_path ) ) virtual,
          -- doc_fad_id            text not null references #{prefix}fads,
          -- doc_file_parameters   json not null,
        primary key ( doc_file_id ) );"""
    #.......................................................................................................
    self = @
    @db.create_table_function
      name:         "lines_of"
      parameters:   [ 'doc_file_id', ]
      columns:      [ 'doc_line_nr', 'doc_line_txt', 'doc_par_nr', ]
      rows:         ( doc_file_abspath ) ->
        doc_line_nr   = 0
        doc_par_nr    = 0
        prv_was_blank = true
        for doc_line_txt from GUY.fs.walk_lines doc_file_abspath
          doc_par_nr++ if ( not ( is_blank = self.text_is_blank doc_line_txt ) ) and prv_was_blank
          prv_was_blank = is_blank
          doc_line_nr++
          yield { doc_line_nr, doc_par_nr: ( if is_blank then 0 else doc_par_nr ), doc_line_txt, }
        return null
    #.......................................................................................................
    @db SQL"""
      create view #{prefix}lines as select
          f.doc_file_id               as doc_file_id,
          l.doc_line_nr               as doc_line_nr,
          l.doc_par_nr                as doc_par_nr,
          l.doc_line_txt              as doc_line_txt
          -- is_blank( l.doc_line_txt )  as doc_line_is_blank
        from #{prefix}files             as f,
        lines_of( f.doc_file_abspath )  as l
        order by 1, 2;"""
    #.......................................................................................................
    @_insert_file     = @db.prepare_insert { into: "#{prefix}files", returning: '*', }
    return null

  #---------------------------------------------------------------------------------------------------------
  get_doc_file_abspath: ( doc_file_path ) -> PATH.resolve @cfg.home, doc_file_path
  text_is_blank:        ( text          ) -> text is '' or /^\s*$/.test text

  #---------------------------------------------------------------------------------------------------------
  get_doc_file_ids:   Decorators.get_all_first_values 'files',      'doc_file_id'
  # get_doc_fads:       Decorators.get_all_rows         'fads'

  #---------------------------------------------------------------------------------------------------------
  add_file: ( cfg ) ->
    cfg = @types.create.doc_add_file_cfg cfg
    { doc_file_id
      doc_file_path
      doc_file_hash } = cfg
    doc_file_abspath  = @get_doc_file_abspath doc_file_path
    doc_file_hash    ?= GUY.fs.get_content_hash doc_file_abspath, { fallback: null, }
    return @db.first_row @_insert_file, { doc_file_id, doc_file_path, doc_file_hash, }


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





