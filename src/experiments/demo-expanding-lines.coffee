

'use strict'

############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DTML/EXP/EXPAND'
debug                     = CND.get_logger 'debug',     badge
warn                      = CND.get_logger 'warn',      badge
info                      = CND.get_logger 'info',      badge
urge                      = CND.get_logger 'urge',      badge
help                      = CND.get_logger 'help',      badge
whisper                   = CND.get_logger 'whisper',   badge
echo                      = CND.echo.bind CND
#...........................................................................................................
FS                        = require 'fs'
PATH                      = require 'path'
PD                        = require 'pipedreams'
{ $
  $watch
  $async
  select
  stamp }                 = PD
{ assign
  jr }                    = CND
first                     = Symbol 'first'
last                      = Symbol 'last'
#...........................................................................................................
types                     = require '../types'
{ isa
  validate
  declare
  size_of
  type_of }               = types
#...........................................................................................................
require                   '../exception-handler'
MIRAGE                    = require 'mkts-mirage'
do_validate               = true
DATAMILL                  = require '../..'
{ cwd_abspath
  cwd_relpath
  here_abspath
  _drop_extension
  project_abspath }       = require '../helpers'

#-----------------------------------------------------------------------------------------------------------
format_object = ( d ) ->
  R = {}
  R[ k ] = d[ k ] for k in ( k for k of d ).sort()
  return jr R

#-----------------------------------------------------------------------------------------------------------
@new_datom = ( P ... ) ->
  R           = PD.thaw PD.new_datom P...
  R.vnr_txt   = ( jr R.$vnr ) if ( not R.vnr_txt )? and ( R.$vnr? )
  R.$fresh    = true
  return PD.freeze R

#-----------------------------------------------------------------------------------------------------------
@new_vnr_level = ( vnr, nr = 1 ) ->
  ### Given a `mirage` instance and a vectorial line number `vnr`, return a copy of `vnr`, call it
  `vnr0`, which has an index of `0` appended, thus representing the pre-first `vnr` for a level of lines
  derived from the one that the original `vnr` pointed to. ###
  validate.nonempty_list vnr
  R = assign [], vnr
  R.push nr
  return R

#-----------------------------------------------------------------------------------------------------------
@advance_vnr = ( vnr ) ->
  ### Given a `mirage` instance and a vectorial line number `vnr`, return a copy of `vnr`, call it
  `vnr0`, which has its last index incremented by `1`, thus representing the vectorial line number of the
  next line in the same level that is derived from the same line as its predecessor. ###
  validate.nonempty_list vnr
  R                    = assign [], vnr
  R[ vnr.length - 1 ] += +1
  return R

#-----------------------------------------------------------------------------------------------------------
@$split_words = ( S ) -> $ ( d, send ) =>
  return send d unless select d, '^mktscript'
  #.........................................................................................................
  send stamp d
  text      = d.value
  prv_vnr   = d.$vnr
  nxt_vnr  = @new_vnr_level prv_vnr
  #.........................................................................................................
    # unless isa.blank_text row.value
  for word in text.split /\s+/
    continue if word is ''
    nxt_vnr = @advance_vnr nxt_vnr
    send @new_datom '^word', { text: word, $vnr: nxt_vnr, }
  #.........................................................................................................
  return null

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
    $vnr          = @new_vnr_level prv_vnr
    send PD.new_datom '^blank', { value: { linecount, }, $vnr, $fresh: true, }
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
        $vnr  = @new_vnr_level d.$vnr, 1
        d     = PD.set d, 'key',    '^literal'
        d     = PD.set d, '$vnr',   $vnr
        d     = PD.set d, '$fresh', true
      send d
    # $vnr  = @new_vnr_level d.$vnr, 0
    # $vnr  = @advance_vnr $vnr; send PD.new_datom '<codeblock',        { level, $vnr, $fresh: true, }
    # $vnr  = @advance_vnr $vnr; send PD.new_datom '>codeblock',        { level, $vnr, $fresh: true, }
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
    prv_line_is_blank = @previous_line_is_blank S, d.$vnr
    nxt_line_is_blank = @next_line_is_blank     S, d.$vnr
    $vnr              = @new_vnr_level d.$vnr, 0
    unless prv_line_is_blank and nxt_line_is_blank
      ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ###
      ### TAINT update PipeDreams: warnings always marked fresh ###
      # warning = PD.new_warning d.$vnr, message, d, { $fresh: true, }
      message = "µ09082 heading should have blank lines above and below"
      $vnr    = @advance_vnr $vnr; send PD.new_datom '~warning', message, { $vnr, $fresh: true, }
      ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ###
    send stamp d
    level = match.groups.hashes.length
    text  = match.groups.text.replace /^\s*(.*?)\s*$/g, '$1' ### TAINT use trim method ###
    # debug 'µ88764', rpr match.groups.text
    # debug 'µ88764', rpr text
    $vnr  = @advance_vnr $vnr; send PD.new_datom '<h',                { level, $vnr, $fresh: true, }
    $vnr  = @advance_vnr $vnr; send PD.new_datom '^mktscript', text,  { $vnr, $fresh: true, }
    $vnr  = @advance_vnr $vnr; send PD.new_datom '>h',                { level, $vnr, $fresh: true, }
    return null

#-----------------------------------------------------------------------------------------------------------
@previous_line_is_blank = ( S, vnr ) ->
  return true unless ( d = @get_previous_datom S, vnr )?
  return ( d.value.match /^\s*$/ )?

#-----------------------------------------------------------------------------------------------------------
@next_line_is_blank = ( S, vnr ) ->
  return true unless ( d = @get_next_datom S, vnr )?
  return ( d.value.match /^\s*$/ )?

#-----------------------------------------------------------------------------------------------------------
@get_previous_datom = ( S, vnr ) ->
  ### TAINT consider to use types ###
  unless vnr.length is 1
    throw new Error "µ33442 `get_next_datom()` not supported for nested vnrs, got #{rpr vnr}"
  ### TAINT need inverse to advance ###
  return null unless vnr[ 0 ] > 1
  vnr_txt = jr [ vnr[ 0 ] - 1 ]
  return @datom_from_vnr S, S, vnr

#-----------------------------------------------------------------------------------------------------------
@get_next_datom = ( S, vnr ) ->
  ### TAINT consider to use types ###
  unless vnr.length is 1
    throw new Error "µ33442 `get_next_datom()` not supported for nested vnrs, got #{rpr vnr}"
  return @datom_from_vnr S, @advance_vnr vnr

#-----------------------------------------------------------------------------------------------------------
@datom_from_vnr = ( S, vnr ) ->
  dbr     = S.mirage.dbr
  vnr_txt = jr vnr
  return null unless ( row = dbr.$.first_row dbr.datom_from_vnr { vnr_txt, } )?
  return @datom_from_row S, row

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

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@datom_from_row = ( S, row ) ->
  ### TAINT how to convert vnr in ICQL? ###
  vnr_txt     = row.vnr_txt
  $vnr        = JSON.parse vnr_txt
  R           = PD.new_datom row.key, { value: row.value, $vnr, }
  R           = PD.set R, '$stamped', true if row.stamped
  return R

#-----------------------------------------------------------------------------------------------------------
@row_from_datom = ( S, d ) ->
  ### TAINT how to convert booleans in ICQL? ###
  stamped   = if d.$stamped then 1 else 0
  vnr_txt   = jr d.$vnr
  value     = if ( isa.text d.value ) then d.value else jr d.value
  R         = { key: d.key, vnr_txt, value, stamped, }
  # MIRAGE.types.validate.mirage_main_row R if do_validate
  return R

#-----------------------------------------------------------------------------------------------------------
@feed_source = ( S, source, limit = Infinity ) ->
  dbr = S.mirage.db
  nr  = 0
  #.........................................................................................................
  for row from dbr.read_unstamped_lines()
    nr += +1
    break if nr > limit
    source.send @datom_from_row S, row
  #.........................................................................................................
  source.end()
  return null

#-----------------------------------------------------------------------------------------------------------
@$feed_db = ( S ) ->
  dbw = S.mirage.dbw
  return $watch ( d ) =>
    ### TAINT how to convert vnr in ICQL? ###
    row = @row_from_datom S, d
    try
      ### TAINT consider to use upsert instead https://www.sqlite.org/lang_UPSERT.html ###
      if      d.$fresh then dbw.insert row
      else if d.$dirty then dbw.update row
    catch error
      warn "µ12133 when trying to insert or update row #{jr row}"
      warn "µ12133 an error occurred:"
      warn "µ12133 #{error.message}"
      throw error
    return null

#-----------------------------------------------------------------------------------------------------------
@_$show = ( S ) -> $watch ( d ) =>
  if d.$stamped then color = CND.grey
  else
    switch d.key
      when '^word' then color = CND.gold
      else color = CND.white
  info color jr d

#-----------------------------------------------------------------------------------------------------------
@show_overview = ( S ) ->
  dbr = S.mirage.db
  #.........................................................................................................
  for row from dbr.read_lines { limit: 30, }
    # debug 'µ10001', rpr row
    if row.stamped
      color = CND.grey
    else
      color = switch row.key
        when '^mktscript' then CND.yellow
        when '^blank'     then ( P... ) -> CND.grey P...
        when '~warning'   then ( P... ) -> CND.reverse CND.red P...
        else CND.white
    key   = row.key.padEnd      12
    vnr   = row.vnr_txt.padEnd  12
    value = if ( isa.text row.value ) then row.value else rpr row.value
    value = value[ .. 80 ]
    info color "#{vnr} #{( if row.stamped then 'S' else ' ' )} #{key} #{rpr value}"
  #.........................................................................................................
  for row from dbr.get_stats()
    info "#{row.key}: #{row.count}"
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@run_phase = ( S, transform ) -> new Promise ( resolve, reject ) =>
  source    = PD.new_push_source()
  pipeline  = []
  pipeline.push source
  pipeline.push transform
  pipeline.push @$feed_db S
  pipeline.push PD.$drain => resolve()
  PD.pull pipeline...
  @feed_source S, source

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
  @show_overview S
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

