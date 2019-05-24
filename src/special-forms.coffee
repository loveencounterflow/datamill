
'use strict'


############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DATAMILL/SPECIAL-FORMS'
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
PD                        = require 'pipedreams'
{ $
  $async
  select
  stamp }                 = PD
#...........................................................................................................
{ jr
  copy
  is_empty
  assign }                = CND
join                      = ( x, joiner = '' ) -> x.join joiner
rprx                      = ( d ) -> "#{d.mark} #{d.type}:: #{jr d.value} #{jr d.stamped ? false}"


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
    ### using ad-hoc `clean` attribute to indicate that text does not contain active characters ###
    return send d unless ( select d, '^text' ) and ( not d.clean )
    if ( parts = @split_on_first_active_chr d.value )?
      { achr, achrs, left, right, } = parts
      send PD.new_single_event 'achr-split', achrs, { achr, left, right, }, $: d
    else
      d.clean = true
      send d
    return null

#-----------------------------------------------------------------------------------------------------------
@$recycle_untouched_texts = ( S ) -> $ ( d, send ) =>
  if ( select d, '^text' ) and ( not d.clean )
    send PD.R.recycling d
  else if ( select d, '^achr-split' )
    send PD.new_text_event d.left + d.value, { clean: true, $: d } unless is_empty d.left
    send PD.R.recycling PD.new_text_event d.right, $: d
  else
    send d
  return null

#-----------------------------------------------------------------------------------------------------------
@$filter_empty_texts = ( S ) -> PD.$filter ( d ) => not ( ( select d, '^text' ) and ( d.value is '' ) )

#-----------------------------------------------------------------------------------------------------------
@$consolidate_texts = ( S ) ->
  buffer = []
  return $ { last: null, }, ( d, send ) =>
    # debug '93093-1', jr d
    if d?
      if ( select d, '^text' )
        buffer.push d.value
        # whisper '93093-2', buffer
      else
        unless is_empty buffer
          send PD.new_text_event ( buffer.join '' )
          buffer.length = 0
        send d
    else
      # whisper '93093-3', buffer
      unless is_empty buffer
        send PD.new_text_event ( buffer.join '' )
        buffer.length = 0
    return null

#-----------------------------------------------------------------------------------------------------------
@$handle_remaining_achrs = ( S ) -> $ ( d, send ) =>
    if ( select d, '^achr-split' )
      lnr     = d.$?.lnr  ? '?'
      text    = if d.$?.text? then ( rpr d.$.text ) else '?'
      message = "unhandled active characters #{rpr d.value} on line #{lnr} in #{text}"
      send PD.new_text_event d.left, { clean: true, $: d } unless is_empty d.left
      send PD.new_warning 'µ99823', message, d, $: d
      # send PD.new_text_event d.left + d.value + d.right, $: d
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
    if ( select d, '^achr-split' ) and ( d.value is start_stop )
      ### using ad-hoc `clean` attribute to indicate that text does not contain active characters ###
      send PD.new_text_event d.left, { clean: true, $: d }
      #.....................................................................................................
      if within
        send PD.new_event closing_key, null, $: d
        within = false
      #.....................................................................................................
      else
        send PD.new_event opening_key, null, $: d
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


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$parse_special_forms = ( S ) =>
  refillable  = []
  bysource    = PD.new_refillable_source refillable, { repeat: 5, show: true, }
  byline      = []
  byline.push bysource
  byline.push PD.$show title: '(parse_special_forms bystream)'
  bystream    = PD.pull byline...
  #.......................................................................................................
  pipeline    = []
  pipeline.push PD.$pass() ### necessary so `$wye()` doesn't come on top of pipeline ###
  pipeline.push PD.$wye bystream
  # pipeline.push PD.R.$unwrap_recycled()
  pipeline.push @$split_on_first_active_chr         S
  pipeline.push @$mark                              S
  pipeline.push @$ins                               S
  pipeline.push @$strike                            S
  pipeline.push @$em_and_strong                     S
  pipeline.push @$em                                S
  pipeline.push @$strong                            S
  pipeline.push @$recycle_untouched_texts           S
  pipeline.push @$filter_empty_texts                S
  pipeline.push @$handle_remaining_achrs            S
  # pipeline.push $ { last: PD.symbols.last, }, ( d, send ) ->
  #   debug '33783', '---------------->', d
  #   if d is PD.symbols.last
  #     refillable.push PD.symbols.end
  #   else
  #     send d
  #   return null
  # pipeline.push PD.$watch ( d ) => if ( select d, '~end' ) then source.end()
  # pipeline.push PD.R.$recycle ( d ) -> refillable.push d
  pipeline.push @$consolidate_texts                 S
  #.......................................................................................................
  return PD.pull pipeline...


