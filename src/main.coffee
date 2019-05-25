




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
@SF                       = require './special-forms'
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




#-----------------------------------------------------------------------------------------------------------
### TAINT to be written; observe this will simplify `$blank_lines()`. ###
@$trim = ( S ) ->
  return $ ( d, send ) => send d

#-----------------------------------------------------------------------------------------------------------
@$blank_lines = ( S ) ->
  prv_vnr       = null
  linecount     = 0
  send          = null
  within_blank  = false
  # is_first      = true
  #.........................................................................................................
  flush = ( n ) =>
    within_blank  = false
    $vnr          = VNR.new_level prv_vnr
    send H.fresh_datom '^blank', { value: { linecount, }, $vnr, }
    linecount     = 0
  #.........................................................................................................
  return $ { last, }, ( d, send_ ) =>
    send = send_
    #.......................................................................................................
    if d is last
      flush()# if within_blank
      return null
    #.......................................................................................................
    return send d unless select d, '^mktscript'
    #.......................................................................................................
    unless isa.blank_text d.value
      flush() if within_blank
      prv_vnr       = d.$vnr
      return send d
    #.......................................................................................................
    send stamp d
    prv_vnr       = d.$vnr
    linecount     = 0 unless within_blank
    linecount    += +1
    within_blank  = true
    return null

#-----------------------------------------------------------------------------------------------------------
@$codeblocks = ( S ) ->
  ### Recognize codeblocks as regions delimited by triple backticks. Possible extensions include
  markup for source code category and double service as pre-formatted blocks. ###
  pattern           = /// ^ (?<backticks> ``` ) $ ///
  within_codeblock  = false
  #.........................................................................................................
  return $ ( d, send ) =>
    return send d unless select d, '^mktscript'
    ### TAINT should send `<codeblock` datom ###
    if ( match = d.value.match pattern )?
      within_codeblock = not within_codeblock
      send stamp d
    else
      if within_codeblock
        ### TAINT should somehow make sure properties are OK for a `^literal` ###
        $vnr  = VNR.new_level d.$vnr, 1
        d     = PD.set d, 'key',    '^literal'
        d     = PD.set d, '$vnr',   $vnr
        d     = PD.set d, '$fresh', true
      send d
    # $vnr  = VNR.new_level d.$vnr, 0
    # $vnr  = VNR.advance $vnr; send H.fresh_datom '<codeblock',        { level, $vnr, }
    # $vnr  = VNR.advance $vnr; send H.fresh_datom '>codeblock',        { level, $vnr, }
    return null

#-----------------------------------------------------------------------------------------------------------
@$heading = ( S ) ->
  ### Recognize heading as any line that starts with a `#` (hash). Current behavior is to
  check whether both prv and nxt lines are blank and if not so issue a warning; this detail may change
  in the future. ###
  pattern = /// ^ (?<hashes> \#+ ) (?<text> .* ) $ ///
  #.........................................................................................................
  return $ ( d, send ) =>
    return send d unless select d, '^mktscript'
    return send d unless ( match = d.value.match pattern )?
    prv_line_is_blank = H.previous_line_is_blank  S, d.$vnr
    nxt_line_is_blank = H.next_line_is_blank      S, d.$vnr
    $vnr              = VNR.new_level d.$vnr, 0
    unless prv_line_is_blank and nxt_line_is_blank
      ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ###
      ### TAINT update PipeDreams: warnings always marked fresh ###
      # warning = PD.new_warning d.$vnr, message, d, { $fresh: true, }
      message = "µ09082 heading should have blank lines above and below"
      $vnr    = VNR.advance $vnr; send H.fresh_datom '~warning', message, { $vnr, }
      ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ###
    send stamp d
    level = match.groups.hashes.length
    text  = match.groups.text.replace /^\s*(.*?)\s*$/g, '$1' ### TAINT use trim method ###
    # debug 'µ88764', rpr match.groups.text
    # debug 'µ88764', rpr text
    $vnr  = VNR.advance $vnr; send H.fresh_datom '<h',                { level, $vnr, }
    $vnr  = VNR.advance $vnr; send H.fresh_datom '^mktscript', text,  { $vnr, }
    $vnr  = VNR.advance $vnr; send H.fresh_datom '>h',                { level, $vnr, }
    return null

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$phase_100 = ( S ) ->
  pipeline = []
  pipeline.push @$trim S
  pipeline.push @$blank_lines S
  return PD.pull pipeline...

#-----------------------------------------------------------------------------------------------------------
@$phase_200 = ( S ) ->
  pipeline = []
  pipeline.push @$codeblocks  S
  pipeline.push @$heading     S
  return PD.pull pipeline...

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
  S         = { mirage, }
  limit     = Infinity
  phases    = [
    '$phase_100'
    '$phase_200'
    ]
  #.........................................................................................................
  for phase in phases
    transform = @[ phase ] S
    help "phase #{rpr phase}"
    await @run_phase S, transform
  H.show_overview S
  resolve()
  #.........................................................................................................
  return null


############################################################################################################
unless module.parent?
  do =>
    #.......................................................................................................
    settings =
      file_path:  project_abspath './src/tests/demo.md'
      db_path:    '/tmp/mirage.db'
      icql_path:  project_abspath './db/datamill.icql'
    mirage = await MIRAGE.create settings
    await @translate_document mirage
    help 'ok'





