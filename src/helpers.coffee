

'use strict'



############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DATAMILL/HELPERS'
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
PATH                      = require 'path'
VNR                       = require './vnr'
{ to_width
  width_of }              = require 'to-width'
#...........................................................................................................
PD                        = require 'pipedreams'
{ $
  $watch
  $async
  select
  stamp }                 = PD
#...........................................................................................................
types                     = require './types'
{ isa
  validate
  declare
  size_of
  type_of }               = types


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@cwd_abspath              = CND.cwd_abspath
@cwd_relpath              = CND.cwd_relpath
@here_abspath             = CND.here_abspath
@_drop_extension          = ( path ) => path[ ... path.length - ( PATH.extname path ).length ]
@project_abspath          = ( P... ) => CND.here_abspath __dirname, '..', P...

#-----------------------------------------------------------------------------------------------------------
@badge_from_filename = ( filename ) ->
  basename  = PATH.basename filename
  return 'DATAMILL/' + ( basename .replace /^(.*?)\.[^.]+$/, '$1' ).toUpperCase()




#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@format_object = ( d ) =>
  R = {}
  R[ k ] = d[ k ] for k in ( k for k of d ).sort()
  return jr R

#-----------------------------------------------------------------------------------------------------------
@new_datom = ( P ... ) =>
  R = PD.new_datom P...
  # R = PD.set R, 'vnr_txt',  ( jr R.$vnr ) if R.$vnr?
  return R

#-----------------------------------------------------------------------------------------------------------
@fresh_datom = ( P ... ) =>
  R = PD.new_datom P...
  # R = PD.set R, 'vnr_txt',  ( jr R.$vnr ) if R.$vnr?
  R = PD.set R, '$fresh',    true
  return R

#-----------------------------------------------------------------------------------------------------------
@swap_key = ( d, key, $vnr = null ) ->
  ### Given a datom `d`, compute the first `$vnr` for the next level (or use the optional `$vnr` argument)
  and set the `key` on a copy. Make sure `$fresh` is set and `$dirty` is unset.
  ###
  $vnr ?= VNR.new_level d.$vnr, 1
  R     = d
  R     = PD.set    R, 'key',    key
  R     = PD.set    R, '$vnr',   $vnr
  R     = PD.set    R, '$fresh', true
  R     = PD.unset  R, '$dirty'
  return R


#===========================================================================================================
# DB QUERIES
#-----------------------------------------------------------------------------------------------------------
@previous_line_is_blank = ( S, vnr ) =>
  return true unless ( d = @get_previous_datom S, vnr )?
  return ( d.text? and d.text.match /^\s*$/ )?

#-----------------------------------------------------------------------------------------------------------
@next_line_is_blank = ( S, vnr ) =>
  return true unless ( d = @get_next_datom S, vnr )?
  return ( d.text? and d.text.match /^\s*$/ )?

#-----------------------------------------------------------------------------------------------------------
@get_previous_datom = ( S, vnr ) =>
  ### TAINT consider to use types ###
  unless vnr.length is 1
    throw new Error "µ33442 `get_next_datom()` not supported for nested vnrs, got #{rpr vnr}"
  ### TAINT need inverse to advance ###
  return null unless vnr[ 0 ] > 1
  vnr_txt = jr [ vnr[ 0 ] - 1 ]
  return @datom_from_vnr S, S, vnr

#-----------------------------------------------------------------------------------------------------------
@get_next_datom = ( S, vnr ) =>
  ### TAINT consider to use types ###
  unless vnr.length is 1
    throw new Error "µ33442 `get_next_datom()` not supported for nested vnrs, got #{rpr vnr}"
  return @datom_from_vnr S, VNR.advance vnr

#-----------------------------------------------------------------------------------------------------------
@row_from_vnr = ( S, vnr ) =>
  dbr     = S.mirage.dbr
  vnr_txt = jr vnr
  return dbr.$.first_row dbr.datom_from_vnr { vnr_txt, }

#-----------------------------------------------------------------------------------------------------------
@datom_from_vnr = ( S, vnr ) =>
  return null unless ( row = @row_from_vnr S, vnr )?
  return @datom_from_row S, row

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@datom_from_row = ( S, row ) =>
  ### TAINT how to convert vnr in ICQL? ###
  vnr_txt     = row.vnr_txt
  $vnr        = JSON.parse vnr_txt
  p           = JSON.parse row.p
  R           = PD.thaw PD.new_datom row.key, { $vnr, }
  R.text      = row.text  if row.text?
  R.$stamped  = true      if ( row.stamped ? false )
  R[ k ]      = p[ k ] for k of p when p[ k ]?
  return PD.freeze R

#-----------------------------------------------------------------------------------------------------------
@p_from_datom = ( S, d ) =>
  R     = {}
  count = 0
  for k, v of d
    continue if k is 'key'
    continue if k is 'text'
    continue if k.startsWith '$'
    continue unless v?
    count  += 1
    R[ k ]  = v
  R = null if count is 0
  return JSON.stringify R

#-----------------------------------------------------------------------------------------------------------
@row_from_datom = ( S, d ) =>
  ### TAINT how to convert booleans in ICQL? ###
  key       = d.key
  stamped   = if ( PD.is_stamped d ) then 1 else 0
  vnr_txt   = JSON.stringify d.$vnr
  text      = d.text ? null
  p         = @p_from_datom S, d
  R         = { key, vnr_txt, text, p, stamped, }
  # MIRAGE.types.validate.mirage_main_row R if do_validate
  return R

#-----------------------------------------------------------------------------------------------------------
@feed_source = ( S, source, limit = Infinity ) =>
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
@$feed_db = ( S ) =>
  dbw = S.mirage.dbw
  return $watch ( d ) =>
    ### TAINT how to convert vnr in ICQL? ###
    row = @row_from_datom S, d
    try
      ### TAINT consider to use upsert instead https://www.sqlite.org/lang_UPSERT.html ###
      ### NOTE Make sure to test first for `$fresh`/inserts, then for `$dirty`/updates, since a `$fresh`
      datom may have undergone changes (which doesn't make the correct opertion an update). ###
      if      d.$fresh then dbw.insert row
      else if d.$dirty then dbw.update row
    catch error
      warn 'µ12133', "when trying to insert or update row"
      warn 'µ12133', jr row
      warn 'µ12133', "an error occurred:"
      warn 'µ12133', "#{error.message}"
      if error.message.startsWith 'UNIQUE constraint failed'
        urge 'µ88768', "conflict occurred because"
        urge 'µ88768', jr @row_from_vnr S, d.$vnr
        urge 'µ88768', "is already in DB"
      throw error
    return null


#===========================================================================================================
# PHASES
#-----------------------------------------------------------------------------------------------------------
@repeat_phase = ( S, phase ) =>
  validate.datamill_phase_repeat phase.repeat_phase
  return false unless phase.repeat_phase?
  return phase.repeat_phase if isa.boolean phase.repeat_phase
  return phase.repeat_phase S


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$show = ( S ) => $watch ( d ) =>
  if d.$stamped then color = CND.grey
  else
    switch d.key
      when '^word' then color = CND.gold
      else color = CND.white
  info color jr d

#-----------------------------------------------------------------------------------------------------------
@get_tty_width = ( S ) =>
  return R if ( R = process.stdout.columns )?
  { execSync, } = require 'child_process'
  return parseInt ( execSync "tput cols", { encoding: 'utf-8', } ), 10

#-----------------------------------------------------------------------------------------------------------
@show_overview = ( S, raw = false ) =>
  ### TAINT consider to convert row to datom before display ###
  line_width  = @get_tty_width S
  dbr         = S.mirage.db
  level       = 0
  omit_count  = 0
  #.........................................................................................................
  for row from dbr.read_lines() # { limit: 30, }
    if raw
      info @format_object row
      continue
    if ( row.key is '^mktscript' ) and ( row.value is '' )
      omit_count += +1
      continue
    if ( row.key is '^blank' )
      echo CND.white '-'.repeat line_width
      continue
    switch row.key
      when '^mktscript' then  _color  = CND.YELLOW
      when '^blank'     then  _color  = CND.grey
      when '~warning'   then  _color  = CND.RED
      when '~notice'    then  _color  = CND.cyan
      when '^literal'   then  _color  = CND.GREEN
      when '<h'         then  _color  = CND.VIOLET
      when '>h'         then  _color  = CND.VIOLET
      else                    _color  = CND.white
    key   = row.key.padEnd      12
    vnr   = row.vnr_txt.padEnd  12
    text  = if row.text?  then ( jr row.text      ) else ''
    p     = if row.p?     then row.p                else ''
    p     = '' if ( not p? ) or ( p is 'null' )
    value = text + ' ' + p
    value = value[ .. 80 ]
    stamp = if row.stamped then 'S' else ' '
    line  = "#{vnr} #{stamp} #{key} #{value}"
    line  = to_width line, line_width
    dent  = '  '.repeat level
    level = switch row.key[ 0 ]
      when '<' then level + 1
      when '>' then level - 1
      else          level
    color = if row.stamped then CND.grey else ( P... ) -> CND.reverse _color P...
    # color = if row.stamped then _color else ( P... ) -> CND.reverse _color P...
    echo dent + color line
  #.........................................................................................................
  echo "#{omit_count} rows omitted from this view"
  for row from dbr.get_stats()
    echo "#{row.key}: #{row.count}"
  #.........................................................................................................
  return null


