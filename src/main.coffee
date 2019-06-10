




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
@run_phase = ( S, transform ) -> new Promise ( resolve, reject ) =>
  source    = PD.new_push_source()
  pipeline  = []
  pipeline.push source
  pipeline.push transform
  # pipeline.push @$validate_symmetric_keys()
  pipeline.push H.$feed_db S
  pipeline.push PD.$drain => resolve()
  PD.pull pipeline...
  H.feed_source S, source

#-----------------------------------------------------------------------------------------------------------
@new_datamill = ( mirage ) ->
  R =
    mirage:     mirage
  return R

#-----------------------------------------------------------------------------------------------------------
@translate_document = ( mirage ) -> new Promise ( resolve, reject ) =>
  S           = @new_datamill mirage
  limit       = Infinity
  phase_names = [
    './000-initialize'
    './005-start-stop'
    './006-ignore'
    './010-whitespace-1'
    './020-blocks'
    './025-whitespace-2'
    # './030-1-paragraphs-breaks'
    # './030-2-paragraphs-consolidate'
    # './040-markdown-inline'
    # './030-escapes'
    # './035-special-forms'
    './xxx-validation'
    ]
  #.........................................................................................................
  XXX_count = 0
  loop
    XXX_count += +1
    break if XXX_count > 1
    debug 'µ33982', "run-through #{XXX_count}"
    for phase_name in phase_names
      phase     = require phase_name
      pass_max  = 5
      pass      = 0
      loop
        pass += +1
        if pass >= pass_max
          warn "µ44343 enforced break, pass_max is #{pass_max}"
          break
        help 'µ55567 ' + ( CND.reverse CND.yellow " pass #{pass} " ) + ( CND.lime " phase #{phase_name} " )
        await @run_phase S, phase.$transform S
        break unless H.repeat_phase S, phase
        warn "µ33443 repeating phase #{phase_name}"
  #.........................................................................................................
  # H.show_overview S, { hilite: '^blank', }
  H.show_overview S
  resolve()
  #.........................................................................................................
  return null


############################################################################################################
unless module.parent?
  do =>
    #.......................................................................................................
    settings =
      file_path:    project_abspath './src/tests/demo.md'
      # file_path:    project_abspath './src/tests/demo-simple-paragraphs.md'
      # db_path:      ':memory:'
      db_path:      project_abspath './db/datamill.db'
      icql_path:    project_abspath './db/datamill.icql'
      default_key:  '^line'
      default_dest: 'main'
      clear:        true
    help "using database at #{settings.db_path}"
    mirage  = await MIRAGE.create settings
    await @translate_document mirage
    # db      = mirage.db
    # for row from db.$.query "select * from dest_changes_backward order by vnr_blob;"
    #   delete row.vnr_blob
    #   help jr row
    # for row from db.$.query "select * from dest_changes_forward order by vnr_blob;"
    #   delete row.vnr_blob
    #   info jr row
    # for row from db.read_changed_dest_last_lines()
    #   delete row.vnr_blob
    #   help jr row
    # for row from db.read_changed_dest_first_lines()
    #   delete row.vnr_blob
    #   info jr row
    # help 'ok'
    return null




