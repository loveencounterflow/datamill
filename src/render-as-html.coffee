




'use strict'

############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DATAMILL/MAIN'
debug                     = CND.get_logger 'debug',     badge
warn                      = CND.get_logger 'warn',      badge
info                      = CND.get_logger 'info',      badge
urge                      = CND.get_logger 'urge',      badge
help                      = CND.get_logger 'help',      badge
whisper                   = CND.get_logger 'whisper',   badge
echo                      = CND.echo.bind CND
{ jr
  assign }                = CND
#...........................................................................................................
require                   './exception-handler'
first                     = Symbol 'first'
last                      = Symbol 'last'
MIRAGE                    = require 'mkts-mirage'
VNR                       = require './vnr'
#...........................................................................................................
PD                        = require 'pipedreams'
{ $
  $watch
  $async
  select
  stamp }                 = PD
#...........................................................................................................
@types                    = require './types'
{ isa
  validate
  declare
  first_of
  last_of
  size_of
  type_of }               = @types
#...........................................................................................................
H                         = require './helpers'
{ cwd_abspath
  cwd_relpath
  here_abspath
  project_abspath }       = H




#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@render = ( S ) -> new Promise ( resolve, reject ) =>
  resolve()


############################################################################################################
unless module.parent?
  do =>
    #.......................................................................................................
    settings =
      file_path:    project_abspath './src/tests/demo.md'
      # file_path:    project_abspath './src/tests/demo-medium.md'
      # file_path:    project_abspath './src/tests/demo-simple-paragraphs.md'
      # db_path:      ':memory:'
      db_path:      project_abspath './db/datamill.db'
      icql_path:    project_abspath './db/datamill.icql'
      default_key:  '^line'
      default_dest: 'main'
      clear:        true
    help "using database at #{settings.db_path}"
    mirage  = await MIRAGE.create settings
    await @parse_document mirage
    await @render_as_html mirage
    #.......................................................................................................
    db              = mirage.db
    first_vnr_blob  = db.$.as_hollerith [ 42, 0, ]
    last_vnr_blob   = db.$.as_hollerith [ 42, 0, ]
    for row from db.read_unstamped_lines { first_vnr_blob, last_vnr_blob, }
      info jr H.datom_from_row null, row
      # { prv_dest, dest, stamped, key, } = row
      # info jr { prv_dest, dest, stamped, key, }
    #.......................................................................................................
    # for row from db.$.query "select * from dest_changes_forward order by vnr_blob;"
    #   { prv_dest, dest, stamped, key, } = row
    #   info jr { prv_dest, dest, stamped, key, }
    # for row from db.read_changed_dest_last_lines()
    #   delete row.vnr_blob
    #   help jr row
    # for row from db.read_changed_dest_first_lines()
    #   delete row.vnr_blob
    #   info jr row
    # help 'ok'
    return null




