




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
  # pipeline.push H.$show S
  pipeline.push H.$feed_db S
  pipeline.push PD.$drain => resolve()
  PD.pull pipeline...
  H.feed_source S, source

#-----------------------------------------------------------------------------------------------------------
@translate_document = ( mirage ) -> new Promise ( resolve, reject ) =>
  S           = { mirage, }
  limit       = Infinity
  phase_names = [
    './005-stop'
    './010-consolidate-whitespace'
    './020-blocks'
    './040-markdown-inline'
    # './030-escapes'
    # './035-special-forms'
    ]
  #.........................................................................................................
  for phase_name in phase_names
    phase     = require phase_name
    pass_max  = 5
    pass      = 0
    loop
      pass += +1
      if pass >= pass_max
        warn "µ44343 enforced break, pass_max is #{pass_max}"
        break
      help "µ55567 phase #{phase_name} pass #{CND.reverse CND.yellow pass}"
      await @run_phase S, phase.$transform S
      break unless H.repeat_phase S, phase
      warn "µ33443 repeating phase #{phase_name}"
  #.........................................................................................................
  H.show_overview S, false
  # H.show_overview S, true
  resolve()
  #.........................................................................................................
  return null


############################################################################################################
unless module.parent?
  do =>
    #.......................................................................................................
    settings =
      file_path:    project_abspath './src/tests/demo.md'
      db_path:      '/tmp/mirage.db'
      icql_path:    project_abspath './db/datamill.icql'
      default_key:  '^line'
    mirage = await MIRAGE.create settings
    await @translate_document mirage
    help 'ok'





