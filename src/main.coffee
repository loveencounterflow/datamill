




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
@run_phase = ( S, transform ) -> new Promise ( resolve, reject ) =>
  #.........................................................................................................
  $capture_control_messages = ( S ) -> $ ( d, send ) =>
    if select d, '~'
      switch d.key
        when '~datamill-break-phase-and-repeat'
          S.control.push d
        else
          throw new Error "µ98401 unknown system key #{rpr d.key}"
    else
      send d
  #.........................................................................................................
  source    = PD.new_push_source()
  pipeline  = []
  pipeline.push source
  pipeline.push transform
  pipeline.push $capture_control_messages S
  pipeline.push H.$feed_db                S
  pipeline.push PD.$drain => resolve()
  PD.pull pipeline...
  H.feed_source S, source

#-----------------------------------------------------------------------------------------------------------
@new_datamill = ( mirage ) ->
  R =
    mirage:       mirage
    control:
      active_phase: null
      queue:        []    ### A queue for flow control messages ###
      reprise:
        start_vnr:    null
        stop_vnr:     null
        phase:        null  ### name of phase that queued control messages ###
  return R

#-----------------------------------------------------------------------------------------------------------
@_set_active_phase                = ( S, phase_name ) => S.control.active_phase = phase_name
@_cancel_active_phase             = ( S             ) => S.control.active_phase = null
@_length_of_control_queue         = ( S             ) => S.control.queue.length
@_control_queue_has_messages      = ( S             ) => ( @_length_of_control_queue S ) > 0
@_next_control_message_is_from    = ( S, phase_name ) => S.control.queue[ 0 ]?.phase is phase_name
@_is_reprising                    = ( S             ) => S.control.reprise.start_vnr?

#-----------------------------------------------------------------------------------------------------------
@_pluck_next_control_message = ( S ) =>
  throw new Error "µ11092 queue is empty" unless S.control.queue.length > 0
  message = S.control.queue.shift()
  assign S.control.reprise, message
  return message

#-----------------------------------------------------------------------------------------------------------
@reprise = ( S, region ) =>
  validate.datamill_region  region
  validate.nonempty_text    S.control.active_phase
  { start_vnr
    stop_vnr }  = region
  S.control.queue.push PD.new_datom '~reprise', { start_vnr, stop_vnr, phase: S.control.active_phase, }
  return null

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
    # # './030-escapes'
    # # './035-special-forms'
    # './xxx-validation'
    ]
  #.........................................................................................................
  loop
    try
      # ### TAINT use API ###
      # S.confine_to = null
      # S.confine_from_phase = null
      for phase_name in phase_names
        @_set_active_phase S, phase_name
        # length_of_queue = @_length_of_control_queue S
        phase           = require phase_name
        pass            = 1
        help 'µ55567 ' + ( CND.reverse CND.yellow " pass #{pass} " ) + ( CND.lime " phase #{phase_name} " )
        await @run_phase S, phase.$transform S
        #.....................................................................................................
        ### TAINT use proper flag / API ###
        for x in S.control.queue
          debug 'µ09087', jr x
        # if length_of_queue isnt @_length_of_control_queue S
        if @_next_control_message_is_from S, phase_name
          @_cancel_active_phase S
          throw @_pluck_next_control_message S
        #.....................................................................................................
        if H.repeat_phase S, phase
          throw new Error "µ33443 phase repeating not implemented (#{rpr phase_name})"
        @_cancel_active_phase S
    #.........................................................................................................
    catch m
      throw m unless ( select m, '~reprise' )
      info "µ33324 reprising, confined to #{jr m.start_vnr}...#{jr m.stop_vnr}"
      ### TAINT use API ###
      S.confine_to = m
      continue
    break
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
    #   { prv_dest, dest, stamped, key, } = row
    #   info jr { prv_dest, dest, stamped, key, }
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




