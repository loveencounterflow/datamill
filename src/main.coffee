




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
  stamp }                 = PD.export()
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
DATAMILL                  = @



#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@run_phase = ( S, settings, transform ) -> new Promise ( resolve, reject ) =>
  defaults = { from_realm: S.mirage.default_realm, }
  settings = { defaults..., settings..., }
  validate.datamill_run_phase_settings settings
  # debug 'µ33344', jr S
  # source    = H.new_db_source S
  # pipeline  = []
  # pipeline.push source
  # pipeline.push transform
  # pipeline.push H.$feed_db S
  # pipeline.push PD.$drain => resolve()
  # R = PD.pull pipeline...
  source    = PD.new_push_source()
  pipeline  = []
  pipeline.push source
  pipeline.push transform
  pipeline.push H.$feed_db S
  pipeline.push PD.$drain => resolve()
  R = PD.pull pipeline...
  H.feed_source S, source, settings.from_realm
  return null

#-----------------------------------------------------------------------------------------------------------
### TAINT consider to use dedicated DB module akin to mkts-mirage/src/db.coffee ###
@_create_udfs = ( mirage ) ->
  db = mirage.db
  ### Placeholder function re-defined by `H.copy_realm()`: ###
  db.$.function 'datamill_copy_realm_select', { deterministic: false, varargs: false }, ( row ) -> true
  return null

#-----------------------------------------------------------------------------------------------------------
@create = ( settings ) ->
  ### TAINT set active realm ###
  defaults =
    file_path:      null
    # db_path:        ':memory:'
    db_path:        H.project_abspath 'db/datamill.db'
    icql_path:      H.project_abspath 'db/datamill.icql'
    default_key:    '^line'
    default_dest:   'main'
    default_realm:  'input'
    clear:          true
  #.........................................................................................................
  settings  = { defaults..., settings..., }
  mirage    = await MIRAGE.create settings
  #.........................................................................................................
  R         =
    mirage:       mirage
    control:
      active_phase: null
      queue:        []    ### A queue for flow control messages ###
      reprise_nr:   1
      reprise:
        start_vnr:    null
        stop_vnr:     null
        phase:        null  ### name of phase that queued control messages ###
  #.........................................................................................................
  ### TAINT consider to use dedicated DB module akin to mkts-mirage/src/db.coffee ###
  @_create_udfs mirage
  return R

#-----------------------------------------------------------------------------------------------------------
@_set_active_phase                = ( S, phase_name ) => S.control.active_phase = phase_name
@_cancel_active_phase             = ( S             ) => S.control.active_phase = null
@_length_of_control_queue         = ( S             ) => S.control.queue.length
@_control_queue_has_messages      = ( S             ) => ( @_length_of_control_queue S ) > 0
@_next_control_message_is_from    = ( S, phase_name ) => S.control.queue[ 0 ]?.phase is phase_name
@_is_reprising                    = ( S             ) => S.control.reprise.phase?

#-----------------------------------------------------------------------------------------------------------
@_set_to_reprising = ( S, message ) =>
  validate.datamill_reprising_message message
  assign S.control.reprise.phase, message
  S.control.reprise_nr += +1
  return null

#-----------------------------------------------------------------------------------------------------------
@_conclude_current_reprise = ( S ) =>
  S.control.reprise[ key ] = null for key of S.control.reprise
  return null

#-----------------------------------------------------------------------------------------------------------
@_pluck_next_control_message = ( S ) =>
  throw new Error "µ11092 queue is empty" unless S.control.queue.length > 0
  message = S.control.queue.shift()
  assign S.control.reprise, message
  return message

#-----------------------------------------------------------------------------------------------------------
@reprise = ( S, region ) =>
  validate.datamill_inclusive_region  region
  validate.nonempty_text              S.control.active_phase
  ### TAINT use explicit datatype to test for additional condition ###
  validate.nonempty_text              region.ref
  { first_vnr
    last_vnr
    ref       } = region
  S.control.queue.push PD.new_datom '~reprise', { first_vnr, last_vnr, phase: S.control.active_phase, ref, }
  return null

#-----------------------------------------------------------------------------------------------------------
@render_html = ( S, settings ) -> new Promise ( resolve, reject ) =>
  defaults  = { phase_names: [ './900-render-html', ], }
  settings  = { defaults..., settings..., }
  resolve await @parse_document S, settings

#-----------------------------------------------------------------------------------------------------------
@parse_document = ( S, settings ) -> new Promise ( resolve, reject ) =>
  defaults =
    quiet:        false
    phase_names:  [
      './000-initialize'
      './005-start-stop'
      './006-ignore'
      './010-1-whitespace'
      './010-2-whitespace-dst'
      './020-blocks'
      './030-paragraphs'
      './035-hunks'
      './040-markdown-inline'
      # # './030-escapes'
      # # './035-special-forms'
      './xxx-validation'
      # './900-render-html'
      ]
  settings  = { defaults..., settings..., }
  validate.datamill_parse_document_settings settings
  #.........................................................................................................
  msg_1 = ->
    return if settings.quiet
    nrs_txt         = CND.reverse CND.yellow " r#{S.control.reprise_nr} p#{pass} "
    help 'µ55567 ' + nrs_txt + ( CND.lime " phase #{phase_name} " )
  #.........................................................................................................
  msg_2 = ( phase_name ) ->
    return if settings.quiet
    nrs_txt = CND.reverse CND.yellow " r#{S.control.reprise_nr} "
    info 'µ22872', nrs_txt + CND.blue " finished reprise for #{phase_name}"
    info()
  #.........................................................................................................
  msg_2a = ( phase_name ) ->
    return if settings.quiet
    info 'µ22872', CND.blue "continuing without limits"
    info()
  #.........................................................................................................
  msg_3 = ( message ) ->
    return if settings.quiet
    nrs_txt         = CND.reverse CND.yellow " r#{S.control.reprise_nr} "
    info()
    info 'µ33324', nrs_txt + CND.blue " reprise for #{message.phase} with fragment #{jr message.first_vnr} <= vnr <= #{jr message.last_vnr} (ref: #{message.ref})"
  #.........................................................................................................
  loop
    try
      # ### TAINT use API ###
      # S.confine_to = null
      # S.confine_from_phase = null
      for phase_name in settings.phase_names
        @_set_active_phase S, phase_name
        # length_of_queue = @_length_of_control_queue S
        phase           = require phase_name
        pass            = 1
        msg_1()
        await @run_phase S, ( phase.settings ? null ), ( phase.$transform S )
        #...................................................................................................
        if S.control.reprise.phase is phase_name
          ### Conclude reprise; continue with upcoming phase and entire document ###
          ### TAINT do we have to stack boundaries? ###
          msg_2 phase_name
          @_conclude_current_reprise S
        #...................................................................................................
        if @_next_control_message_is_from S, phase_name
          throw @_pluck_next_control_message S
        # msg_2a() unless @_control_queue_has_messages S
        #...................................................................................................
        if H.repeat_phase S, phase
          throw new Error "µ33443 phase repeating not implemented (#{rpr phase_name})"
        @_cancel_active_phase S
    #.......................................................................................................
    catch message
      throw message unless ( select message, '~reprise' )
      @_set_to_reprising S, message
      msg_3 message
      ### TAINT use API ###
      continue
    break
  #.........................................................................................................
  resolve()
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@_demo_list_html_rows = ( S ) -> new Promise ( resolve ) =>
  #.......................................................................................................
  pipeline  = []
  pipeline.push H.new_db_source S, 'html'
  pipeline.push PD.$show()
  pipeline.push PD.$drain -> resolve()
  PD.pull pipeline...

#-----------------------------------------------------------------------------------------------------------
@_demo = ->
  await do => new Promise ( resolve ) =>
    #.......................................................................................................
    settings  =
      # file_path:      project_abspath 'src/tests/demo-short-headlines.md'
      # file_path:      project_abspath 'src/tests/demo.md'
      file_path:      project_abspath 'src/tests/demo-medium.md'
      # file_path:      project_abspath 'src/tests/demo-simple-paragraphs.md'
    #.......................................................................................................
    help "using database at #{settings.db_path}"
    datamill  = await DATAMILL.create settings
    quiet     = false
    quiet     = true
    await DATAMILL.parse_document       datamill, { quiet, }
    await @render_html                  datamill, { quiet, }
    # await @_demo_list_html_rows         datamill
    #.......................................................................................................
    await H.show_overview               datamill
    await H.show_html                   datamill
    HTML = require './900-render-html'
    await HTML.write_to_file datamill
    resolve()
    return null
  return null

############################################################################################################
if module is require.main then do =>
  await DATAMILL._demo()




