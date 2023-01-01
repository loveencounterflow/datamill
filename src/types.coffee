
'use strict'


############################################################################################################
GUY                       = require 'guy'
# { alert
#   debug
#   help
#   info
#   plain
#   praise
#   urge
#   warn
#   whisper }               = GUY.trm.get_loggers 'DATAMILL/TYPES'
{ debug }                 = GUY.trm.get_loggers 'DATAMILL/TYPES'
{ rpr
  inspect
  echo
  log     }               = GUY.trm
{ Intertype }             = require 'intertype'
base_types                = null
server_types              = null
document_types            = null
misfit                    = Symbol 'misfit'
PATH                      = require 'node:path'
{ DBay }                  = require 'dbay'


#-----------------------------------------------------------------------------------------------------------
get_base_types = ->
  return base_types if base_types?
  #.........................................................................................................
  base_types                = new Intertype()
  { declare }               = base_types
  { Document }              = require './document'
  #.........................................................................................................
  declare.dbay                  override: true, isa: ( x ) -> x?.constructor?.name is 'DBay'
  declare.datamill_document     override: true, isa: ( x ) -> x instanceof Document
  #.........................................................................................................
  return base_types

#-----------------------------------------------------------------------------------------------------------
get_server_types = ->
  return server_types if server_types?
  #.........................................................................................................
  server_types                = new Intertype get_base_types()
  { declare }                 = server_types
  #.........................................................................................................
  declare.datamill_host       'nonempty.text'
  declare.datamill_port       ( x ) ->
    return false unless @isa.integer x
    return false unless 1024 <= x <= 65535
    return true
  #.........................................................................................................
  declare.datamill_server_cfg
    fields:
      host:               'datamill_host'
      port:               'datamill_port'
      doc:                'datamill_document'
    default:
      host:               'localhost'
      port:               3456
      paths:
        public:     PATH.resolve __dirname, '../public'
        favicon:    PATH.resolve __dirname, '../public/favicon.png'
        src:        PATH.resolve __dirname, '../src'
      file_server:
        # Enable or disable accepting ranged requests. Disabling this will not send Accept-Ranges and ignore the
        # contents of the Range request header. defaults to true.
        acceptRanges:     true
        # Set Cache-Control response header, defaults to undefined, see docs: Cache-Control in MDN.
        cacheControl:     undefined
        # Enable or disable etag generation, defaults to true.
        etag:             true
        # Enable or disable Last-Modified header, defaults to true. Uses the file system's last modified value.
        # defaults to true.
        lastModified:     true
        # Set ignore rules. defaults to undefined. ( path ) => boolean
        ignore:           undefined
        # If true, serves after await next(), allowing any downstream middleware to respond first. defaults to false.
        defer:            false
  #...........................................................................................................
  return server_types

#-----------------------------------------------------------------------------------------------------------
get_document_types = ->
  return document_types if document_types?
  #.........................................................................................................
  document_types                = new Intertype get_base_types()
  { declare }                   = document_types
  #.........................................................................................................
  declare.doc_fad_id    'nonempty.text'     ### TAINT should check with DB whether known ###
  declare.doc_src_path 'nonempty.text'     ### TAINT should be more precise ###
  declare.doc_src_id    'nonempty.text'     ### TAINT should be more precise ###
  declare.doc_region_id 'nonempty.text'     ### TAINT should be more precise ###
  declare.doc_home      'nonempty.text'     ### TAINT should be more precise ###
  declare.doc_src_hash ( x ) -> ( @isa.text x ) and ( /^[0-9a-f]{17}$/.test x )
  #.........................................................................................................
  declare.doc_document_cfg
    fields:
      db:                 'dbay'
      home:               'doc_home'
      _loc_marker_re:     'regex'
    default:
      db:                 null
      home:               null
      ### TAINT use more permissive identifier syntax ###
      _loc_marker_re:     /<(?<left_slash>\/?)dm:loc#(?<doc_loc_id>[-_a-zA-Z0-9]*)(?<right_slash>\/?)>/ug
    create: ( x ) ->
      return x unless ( not x? ) or ( @isa.object x )
      R     = { @registry.doc_document_cfg.default..., x..., }
      R.db             ?= new DBay()
      return R
  #...........................................................................................................
  declare.doc_add_source_cfg
    fields:
      doc_src_id:        'doc_src_id'
      doc_src_path:      'doc_src_path'
      doc_src_hash:      'optional.doc_src_hash'
      # doc_fad_id:         'doc_fad_id'
    default:
      doc_src_id:        null
      doc_src_path:      null
      doc_src_hash:      null
      # doc_fad_id:         null
  #...........................................................................................................
  declare.doc_update_source_cfg
    fields:
      doc_src_id:        'doc_src_id'
      doc_src_path:      'doc_src_path'
      doc_src_hash:      'doc_src_hash'
    default:
      doc_src_id:        null
      doc_src_path:      null
      doc_src_hash:      null
  #...........................................................................................................
  declare.walk_raw_lines_cfg
    isa:        'optional.list.of.nonempty.text'
    create:     ( x ) ->
      return [] unless x
      return x
  #...........................................................................................................
  declare.walk_xxx_lines_cfg
    isa:        'optional.list.of.nonempty.text'
    create:     ( x ) ->
      return [] unless x
      return x
  #...........................................................................................................
  return document_types

module.exports = { misfit, get_base_types, get_server_types, get_document_types, }



