

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
XXX_COLORIZER             = require './experiments/colorizer'

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
  return @datom_from_vnr S, vnr

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
@register_key = ( S, key, settings ) =>
  validate.datamill_register_key_settings
  db        = S.mirage.dbw
  ### TAINT use API for value conversions ###
  is_block  = if settings.is_block then 1 else 0
  try
    db.register_key { key, is_block, }
  catch error
    throw error unless error.message.startsWith "UNIQUE constraint failed"
    throw new Error "µ77754 key #{rpr key} already registered"
  @_key_registry_cache = null
  return null

#-----------------------------------------------------------------------------------------------------------
@register_or_validate_key = ( S, key, settings ) =>
  validate.datamill_register_key_settings
  db        = S.mirage.dbw
  unless ( entry = db.$.first_row db.get_key_entry { key, } )?
    return @register_key S, key, settings
  definition      = { key, is_block: settings.is_block, }
  ### TAINT use API for value conversions ###
  entry.is_block  = if entry.is_block is 1 then true else false
  unless CND.equals definition, entry
    throw new Error "µ87332 given key definition #{jr definition} doesn't match esisting entry #{rpr entry}"
  return null

#-----------------------------------------------------------------------------------------------------------
@_key_registry_cache = null

#-----------------------------------------------------------------------------------------------------------
@get_key_registry = ( S ) =>
  return @_key_registry_cache if @_key_registry_cache?
  db                    = S.mirage.dbw
  R                     = {}
  R[ row.key ] = row for row from db.read_key_registry()
  @_key_registry_cache  = PD.freeze R
  return R


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@datom_from_row = ( S, row ) =>
  ### TAINT how to convert vnr in ICQL? ###
  # debug 'µ22373', rpr row
  # debug 'µ22373', rpr row.vnr_txt
  # debug 'µ22373', rpr row.p
  vnr_txt     = row.vnr_txt
  $vnr        = JSON.parse vnr_txt
  p           = if row.p? then ( JSON.parse row.p ) else {}
  R           = PD.thaw PD.new_datom row.key, { $vnr, }
  R.dest      = row.dest
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
    continue if k is 'dest'
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
  dest      = d.dest  ? null
  text      = d.text    ? null
  p         = @p_from_datom S, d
  R         = { key, vnr_txt, dest, text, p, stamped, }
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
    row     = @row_from_datom S, d
    methods = []
    try
      ### TAINT consider to use upsert instead https://www.sqlite.org/lang_UPSERT.html ###
      ### NOTE Make sure to test first for `$fresh`/inserts, then for `$dirty`/updates, since a `$fresh`
      datom may have undergone changes (which doesn't make the correct opertion an update). ###
      if d.$fresh
        methods.push 'insert fresh'
        dbw.insert row
      else if d.$dirty
        ### NOTE force insert when update was without effect; this happens when `$vnr` was
        affected by a `PD.set()` call (ex. `VNR.advance $vnr; send PD.set d, '$vnr', $vnr`). ###
        methods.push 'update dirty'
        { changes, } = dbw.update row
        if changes is 0
          methods.push 'insert dirty'
          dbw.insert row
    catch error
      warn 'µ12133', "when trying to #{methods.join ' -> '} row"
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
@show_overview = ( S, settings ) =>
  ### TAINT consider to convert row to datom before display ###
  line_width  = @get_tty_width S
  dbr         = S.mirage.db
  level       = 0
  omit_count  = 0
  #.........................................................................................................
  defaults =
    raw:        false
    hilite:     '^blank'
  settings = assign {}, defaults, settings
  #.........................................................................................................
  for row from dbr.read_lines() # { limit: 30, }
    if settings.raw
      info @format_object row
      continue
    # if ( row.key is '^line' ) and ( row.stamped ) and ( row.text is '' )
    #   omit_count += +1
    #   continue
    # if ( row.stamped )
    #   omit_count += +1
    #   continue
    switch row.key
      when '^line'            then  _color  = CND.YELLOW
      when '^block'           then  _color  = CND.gold
      when '^mktscript'       then  _color  = CND.RED
      when '~warning'         then  _color  = CND.RED
      when '~notice'          then  _color  = CND.cyan
      when '^literal'         then  _color  = CND.GREEN
      when '^literal-blank'   then  _color  = CND.GREEN
      when '^p'               then  _color  = CND.BLUE
      when '<h'               then  _color  = CND.VIOLET
      when '>h'               then  _color  = CND.VIOLET
      else                          _color  = @color_from_text row.key[ 1 .. ]
    #.......................................................................................................
    if false and ( row.key is '^blank' )
      key     = to_width '',          12
      vnr     = to_width '',          12
      dest    = to_width '',          8
      text    = ''
      p       = ''
    #.......................................................................................................
    else
      key     = to_width row.key,     12
      vnr     = to_width row.vnr_txt, 12
      dest    = to_width row.dest,    8
      text    = if row.text?  then ( jr row.text      ) else ''
      p       = if row.p?     then row.p                else ''
      p       = '' if ( not p? ) or ( p is 'null' )
    #.......................................................................................................
    value   = text + ' ' + p
    # value   = value[ .. 80 ]
    stamp   = if row.stamped then 'S' else ' '
    line    = "#{vnr} │ #{dest} │ #{stamp} │ #{key} │ #{value}"
    line    = to_width line, line_width
    dent    = '  '.repeat level
    level   = switch row.key[ 0 ]
      when '<' then level + 1
      when '>' then level - 1
      else          level
    level   = Math.max level, 0
    #.......................................................................................................
    if settings.hilite? and ( settings.hilite is row.key )
      color = ( P... ) -> CND.reverse CND.pink P...
    else if ( row.stamped or row.key is '^blank' )
      color = CND.grey
    else
      color = ( P... ) -> CND.reverse _color P...
    #.......................................................................................................
    echo color line
    # echo dent + color line
  #.........................................................................................................
  echo "#{omit_count} rows omitted from this view"
  for row from dbr.get_stats()
    echo "#{row.key}: #{row.count}"
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
_color_cache = {}
@color_from_text = ( text ) ->
  return R if ( R = _color_cache[ text ] )?
  R = ( P... ) -> ( XXX_COLORIZER.ansi_code_from_text text ) + CND._pen P...
  # R = ( P... ) -> CND.reverse ( XXX_COLORIZER.ansi_code_from_text text ) + CND._pen P...
  _color_cache[ text ] = R
  return R

