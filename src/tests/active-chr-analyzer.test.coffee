

'use strict'

############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DATAMILL/TESTS/ACTIVE-CHRS'
log                       = CND.get_logger 'plain',     badge
info                      = CND.get_logger 'info',      badge
whisper                   = CND.get_logger 'whisper',   badge
alert                     = CND.get_logger 'alert',     badge
debug                     = CND.get_logger 'debug',     badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
urge                      = CND.get_logger 'urge',      badge
echo                      = CND.echo.bind CND
#...........................................................................................................
PATH                      = require 'path'
FS                        = require 'fs'
OS                        = require 'os'
test                      = require 'guy-test'
#...........................................................................................................
PS                        = require '../..'
{ $, $async, }            = PS
#...........................................................................................................
{ jr
  assign
  is_empty }              = CND
defer                     = setImmediate
{ inspect, }              = require 'util'
xrpr                      = ( x ) -> inspect x, { colors: yes, breakLength: Infinity, maxArrayLength: Infinity, depth: Infinity, }


provide_achra = ->
  types                     = require '../types'
  { isa
    validate
    declare
    size_of
    type_of }               = types

  declare 'achra_aform_entry', ( x ) -> @isa.object x

  #-----------------------------------------------------------------------------------------------------------
  @_colorize_groups = ( groups ) ->
    { left
      aform
      right
      move } = groups
    if move is 'open'
      return [
        ( CND.green   left  )
        ( CND.yellow  '<'   )
        ( CND.white   aform )
        ( CND.orange  right )
        ].join ''
    return [
      ( CND.green   left  )
      ( CND.white   aform )
      ( CND.yellow  '>'   )
      ( CND.orange  right )
      ].join ''

  #-----------------------------------------------------------------------------------------------------------
  @achr_pattern   = /// ///u
  @aform          = new Set()

  #-----------------------------------------------------------------------------------------------------------
  @aform_pattern  = /// ///u
  @aforms         = []

  #-----------------------------------------------------------------------------------------------------------
  ### thx to https://stackoverflow.com/a/3561711/7568091 ###
  @_escape_for_regex = ( text ) -> text.replace @_escape_for_regex.pattern, '\\$&'
  @_escape_for_regex.pattern = /[-\/\\^$*+?.()|[\]{}]/g

  #-----------------------------------------------------------------------------------------------------------
  @add_aforms = ( aforms... ) ->
    for aform in aforms
      validate.achra_aform_entry aform
      @aforms.push aform
      k               = aform.open ? aform.single
      k               =
      aform.pattern   = @_escape_for_regex k
    matcher             = ( aform.pattern for aform in @aforms ).join '|'
    @aform_pattern      = /// ^ (?<left> .*? ) (?<aform> #{matcher} ) (?<right> .* ) $ ///
    return null

  #-----------------------------------------------------------------------------------------------------------
  # @add_active_chrs '<', '&', '*', '`', '^', '_', '=', '-', '+', '𣥒'
  @add_aforms { tag: 'code',          open:   '`',  close: '`',  }
  @add_aforms { tag: 'super',         open:   '^',  close: '^',  }
  @add_aforms { tag: 'sub',           open:   '_',  close: '_',  }
  @add_aforms { tag: 'em-or-strong',  single: '***',              }
  @add_aforms { tag: 'strong',        open:   '**', close: '**', }
  @add_aforms { tag: 'em',            open:   '*',  close: '*',  }
  @add_aforms { tag: 'tag',           open:   '<',  close: '>',  }
  @add_aforms { tag: 'ncr',           open:   '&',  close: ';',  }
  # @add_aforms { tag: '',              open:   '=',  close: '=',  }
  # @add_aforms { tag: '',              open:   '-',  close: '-',  }
  # @add_aforms { tag: '',              open:   '+',  close: '+',  }
    # '𣥒': {}
  # help @achr_pattern


  #===========================================================================================================
  #
  #-----------------------------------------------------------------------------------------------------------
  @split_on_next_aform = ( text ) ->
    ### If `text` contains an active character, return a POD with the keys `left`, `achr`, and `right`, where
    `left` holds the (possibly empty) text before the first active character, `achr` holds the active
    character itself, and `right` holds the remaining, again possibly empty, text (that may or may not contain
    further active characters). ###
    return null unless ( match = text.match @aform_pattern )?
    return assign {}, match.groups

  #-----------------------------------------------------------------------------------------------------------
  @advance = ( text ) ->
    stack = []
    top   = -> if ( s = stack.length ) is 0 then null else stack[ s - 1 ]
    while ( groups = @split_on_next_aform text )?
      { left
        aform
        right } = groups
      if ( t = top() ) isnt aform
        stack.push aform
        move = 'open'
      else
        stack.pop()
        move = 'close'
      yield { left, aform, right, move, stack, }
      text = right
    return null

  return @

ACHRA = provide_achra.apply {}

#-----------------------------------------------------------------------------------------------------------
@[ "xxx" ] = ( T, done ) ->
  probes_and_matchers = [
    ["A *short* **demonstration** of `MKTScript`.",2,null]
    ["A *short **demonstration*** of `MKTScript`.",2,null]
    ]
  #.........................................................................................................
  for [ probe, matcher, error, ] in probes_and_matchers
    await T.perform probe, matcher, error, -> new Promise ( resolve ) ->
      for groups from ACHRA.advance probe
        debug 'µ33342', ACHRA._colorize_groups groups
      resolve 2
  #.........................................................................................................
  done()
  return null

  # debug @_escape_for_regex '*'
  # debug @_escape_for_regex '/'
  # debug @_escape_for_regex '^'
  # debug @_escape_for_regex '\\'
  # debug 'foo-bar'.match new RegExp '[x\\-a]'
  # @add_active_chr '-'; help @achr_pattern
  # @add_active_chr '^'; help @achr_pattern


############################################################################################################
unless module.parent?
  test @, { timeout: 5000, }
  # test @[ "wye with duplex pair"            ]


