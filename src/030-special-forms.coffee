




'use strict'

############################################################################################################
H                         = require './helpers'
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = H.badge_from_filename __filename
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
VNR                       = require './vnr'
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


#-----------------------------------------------------------------------------------------------------------
@active_chr_pattern   = /// ///u
@active_chrs          = new Set()

#-----------------------------------------------------------------------------------------------------------
### thx to https://stackoverflow.com/a/3561711/7568091 ###
@_escape_for_regex = ( text ) -> text.replace @_escape_for_regex.pattern, '\\$&'
@_escape_for_regex.pattern = /[-\/\\^$*+?.()|[\]{}]/g

#-----------------------------------------------------------------------------------------------------------
@add_active_chrs = ( chrs... ) ->
  for chr in chrs
    unless ( CND.isa_text chr ) and ( chr.match /^.$/u )?
      throw new Error "expected single character, got #{rpr chr}"
    @active_chrs.add chr
  achrs                 = ( ( @_escape_for_regex chr ) for chr from @active_chrs ).join '|'
  @active_chr_pattern   = /// ^ (?<left> .*? ) (?<achrs> (?<achr> #{achrs} ) \k<achr>* ) (?<right> .* ) $ ///
                        # /// (?<!\\) (?<achr> (?<chr> [ \* ` + p ] ) \k<chr>* ) ///
  return null

#-----------------------------------------------------------------------------------------------------------
@add_active_chrs '<', '&', '*', '`', '^', '_', '=', '-', '+', '𣥒'
# help @active_chr_pattern

# debug @_escape_for_regex '*'
# debug @_escape_for_regex '/'
# debug @_escape_for_regex '^'
# debug @_escape_for_regex '\\'
# debug 'foo-bar'.match new RegExp '[x\\-a]'
# @add_active_chr '-'; help @active_chr_pattern
# @add_active_chr '^'; help @active_chr_pattern


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@split_on_first_active_chr = ( text ) ->
  ### If `text` contains an active character, return a POD with the keys `left`, `achr`, and `right`, where
  `left` holds the (possibly empty) text before the first active character, `achr` holds the active
  character itself, and `right` holds the remaining, again possibly empty, text (that may or may not contain
  further active characters). ###
  return null unless ( match = text.match @active_chr_pattern )?
  return match.groups

#-----------------------------------------------------------------------------------------------------------
@$split_on_first_active_chr = ( S ) ->
  return $ ( d, send ) =>
    return send d unless select d, '^mktscript'
    return send d if d.text is '' ### empty lines are normally stamped out by WS consolidation ###
    # debug 'µ88732', d
    if ( parts = @split_on_first_active_chr d.text )?
      { achr, achrs, left, right, } = parts
      send stamp d
      $vnr = VNR.new_level d.$vnr, 0
      if left? and left isnt ''
        $vnr = VNR.advance $vnr; send H.fresh_datom '^literal', { text: left, $vnr, }
      $vnr = VNR.advance $vnr; send H.fresh_datom '^achr-split', { achrs, achr, right, $vnr, }
    else
      send stamp d
      send H.swap_key d, '^literal'
    return null

#-----------------------------------------------------------------------------------------------------------
@$filter_empty_texts = ( S ) -> PD.$filter ( d ) => not ( ( select d, '^mktscript' ) and ( d.text is '' ) )

# #-----------------------------------------------------------------------------------------------------------
# @$consolidate_texts = ( S ) ->
#   buffer = []
#   return $ { last: null, }, ( d, send ) =>
#     # debug '93093-1', jr d
#     if d?
#       if ( select d, '^mktscript' )
#         buffer.push d.text
#         # whisper '93093-2', buffer
#       else
#         unless isa.empty buffer
#           send PD.new_text_event ( buffer.join '' )
#           buffer.length = 0
#         send d
#     else
#       # whisper '93093-3', buffer
#       unless isa.empty buffer
#         send PD.new_text_event ( buffer.join '' )
#         buffer.length = 0
#     return null

#-----------------------------------------------------------------------------------------------------------
@$handle_remaining_achrs = ( S ) -> $ ( d, send ) =>
    if ( select d, '^achr-split' )
      lnr     = d.$?.lnr  ? '?'
      text    = if d.$?.text? then ( rpr d.$.text ) else '?'
      message = "unhandled active characters #{rpr d.text} on line #{lnr} in #{text}"
      send PD.new_text_event d.left, { clean: true, $: d } unless isa.empty d.left
      send PD.new_warning 'µ99823', message, d, $: d
      # send PD.new_text_event d.left + d.text + d.right, $: d
      # send d
    else
      send d
    return null

#-----------------------------------------------------------------------------------------------------------
@_get_symmetric_achr_transform = ( S, start_stop, name ) ->
  within      = false
  opening_key = "<#{name}"
  closing_key = ">#{name}"
  #.........................................................................................................
  return $ ( d, send ) =>
    if ( select d, '^achr-split' ) and ( d.text is start_stop )
      ### using ad-hoc `clean` attribute to indicate that text does not contain active characters ###
      send PD.new_text_event d.left, { clean: true, $: d }
      #.....................................................................................................
      if within
        send H.fresh_datom closing_key, null, $: d
        within = false
      #.....................................................................................................
      else
        send H.fresh_datom opening_key, null, $: d
        within = true
      #.....................................................................................................
      send PD.new_text_event d.right, $: d
    else
      send d
    return null


#===========================================================================================================
###

Sources:

* https://markdown-it.github.io/
* https://commonmark.org/help/
* https://www.markdownguide.org/basic-syntax

Special Forms:

* *italic*
* **bold**
* ***bold italic***—possibly using underscores, e.g. `_**bold italic**_`, `__*bold italic*__`,
  `*__bold italic__*`, ...
* --strike-- (sometimes using tildes, ~~strike~~)
* ++ins++ (inserted text, used together with `--strike--`)
* ==mark== (highlighted, hilite)
* `code`


###

#-----------------------------------------------------------------------------------------------------------
@$mark          = ( S ) -> @_get_symmetric_achr_transform S, '==',    'mark'
@$ins           = ( S ) -> @_get_symmetric_achr_transform S, '++',    'ins'
@$strike        = ( S ) -> @_get_symmetric_achr_transform S, '--',    'strike'
@$em_and_strong = ( S ) -> @_get_symmetric_achr_transform S, '***',   'em-and-strong'
@$strong        = ( S ) -> @_get_symmetric_achr_transform S, '**',    'strong'
@$em            = ( S ) -> @_get_symmetric_achr_transform S, '*',     'em'



# #-----------------------------------------------------------------------------------------------------------
# @$codeblocks = ( S ) ->
#   ### Recognize codeblocks as regions delimited by triple backticks. Possible extensions include
#   markup for source code category and double service as pre-formatted blocks. ###
#   pattern           = /// ^ (?<backticks> ``` ) $ ///
#   within_codeblock  = false
#   #.........................................................................................................
#   return $ ( d, send ) =>
#     return send d unless select d, '^mktscript'
#     ### TAINT should send `<codeblock` datom ###
#     if ( match = d.text.match pattern )?
#       within_codeblock = not within_codeblock
#       send stamp d
#     else
#       if within_codeblock
#         send stamp d
#         $vnr  = VNR.new_level d.$vnr, 1
#         ### TAINT should somehow make sure properties are OK for a `^literal` ###
#         d1    = d
#         d1    = PD.set d1, 'key',    '^literal'
#         d1    = PD.set d1, '$vnr',   $vnr
#         d1    = PD.set d1, '$fresh', true
#         send d1
#       else
#         send d
#     # $vnr  = VNR.new_level d.$vnr, 0
#     # $vnr  = VNR.advance $vnr; send H.fresh_datom '<codeblock',        { level, $vnr, }
#     # $vnr  = VNR.advance $vnr; send H.fresh_datom '>codeblock',        { level, $vnr, }
#     return null

# #-----------------------------------------------------------------------------------------------------------
# @$heading = ( S ) ->
#   ### Recognize heading as any line that starts with a `#` (hash). Current behavior is to
#   check whether both prv and nxt lines are blank and if not so issue a warning; this detail may change
#   in the future. ###
#   pattern = /// ^ (?<hashes> \#+ ) (?<text> .* ) $ ///
#   #.........................................................................................................
#   return $ ( d, send ) =>
#     return send d unless select d, '^mktscript'
#     return send d unless ( match = d.text.match pattern )?
#     prv_line_is_blank = H.previous_line_is_blank  S, d.$vnr
#     nxt_line_is_blank = H.next_line_is_blank      S, d.$vnr
#     $vnr              = VNR.new_level d.$vnr, 0
#     unless prv_line_is_blank and nxt_line_is_blank
#       ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ###
#       ### TAINT update PipeDreams: warnings always marked fresh ###
#       # warning = PD.new_warning d.$vnr, message, d, { $fresh: true, }
#       message = "µ09082 heading should have blank lines above and below"
#       $vnr    = VNR.advance $vnr; send H.fresh_datom '~warning', message, { $vnr, }
#       ### !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ###
#     send stamp d
#     level = match.groups.hashes.length
#     text  = match.groups.text.replace /^\s*(.*?)\s*$/g, '$1' ### TAINT use trim method ###
#     # debug 'µ88764', rpr match.groups.text
#     # debug 'µ88764', rpr text
#     $vnr  = VNR.advance $vnr; send H.fresh_datom '<h',                { level, $vnr, }
#     $vnr  = VNR.advance $vnr; send H.fresh_datom '^mktscript', text,  { $vnr, }
#     $vnr  = VNR.advance $vnr; send H.fresh_datom '>h',                { level, $vnr, }
#     return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$split_on_first_active_chr         S
  # pipeline.push @$mark                              S
  # pipeline.push @$ins                               S
  # pipeline.push @$strike                            S
  # pipeline.push @$em_and_strong                     S
  # pipeline.push @$em                                S
  # pipeline.push @$strong                            S
  # # pipeline.push @$recycle_untouched_texts           S
  # pipeline.push @$filter_empty_texts                S
  # pipeline.push @$handle_remaining_achrs            S
  # pipeline.push @$consolidate_texts                 S
  return PD.pull pipeline...

