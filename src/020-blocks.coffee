




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
#...........................................................................................................
# ### Whether in-place updates are OK ###
# prefer_updates = true


#-----------------------------------------------------------------------------------------------------------
@$codeblocks = ( S ) ->
  ### Recognize codeblocks as regions delimited by triple backticks. Possible extensions include
  markup for source code category and double service as pre-formatted blocks. ###
  pattern           = /// ^ (?<backticks> ``` ) $ ///
  within_codeblock  = false
  H.register_key S, '<codeblock',     { is_block: true,  }
  H.register_key S, '>codeblock',     { is_block: true,  }
  H.register_key S, '^literal',       { is_block: false, }
  H.register_key S, '^literal-blank', { is_block: false, }
  #.........................................................................................................
  return $ ( d, send ) =>
    if within_codeblock and select d, '^blank'
      return send PD.set d, 'key', '^literal-blank'
    #.......................................................................................................
    return send d unless select d, '^line'
    #.......................................................................................................
    ### line starts or stops codeblock ###
    if ( match = d.text.match pattern )?
      within_codeblock  = not within_codeblock
      dest              = d.dest
      #.....................................................................................................
      if within_codeblock
        send stamp d
        send PD.set ( VNR.deepen d ), 'key', '<codeblock'
      #.....................................................................................................
      else
        send stamp d
        send PD.set ( VNR.deepen d ), 'key', '>codeblock'
    #.......................................................................................................
    ### line is literal within, unchanged outside of codeblock ###
    else
      if within_codeblock
        d = PD.set d, 'key', '^literal'
        send d
      else
        send d
    return null

#-----------------------------------------------------------------------------------------------------------
@$headings = ( S ) ->
  ### Recognize heading as any line that starts with a `#` (hash). Current behavior is to
  check whether both prv and nxt lines are blank and if not so issue a warning; this detail may change
  in the future. ###
  pattern = /// ^ (?<hashes> \#+ ) (?<text> .* ) $ ///
  #.........................................................................................................
  H.register_key S, '<h', { is_block: true, }
  H.register_key S, '>h', { is_block: true, }
  #.........................................................................................................
  return $ ( d, send ) =>
    return send d unless select d, '^line'
    return send d unless ( match = d.text.match pattern )?
    send stamp d
    level = match.groups.hashes.length
    text  = match.groups.text.replace /^\s*(.*?)\s*$/g, '$1' ### TAINT use trim method ###
    dest  = d.dest
    $vnr  = VNR.deepen d.$vnr, 0
    send H.fresh_datom '<h',    { level, $vnr: ( VNR.recede $vnr  ),  dest, }
    send H.fresh_datom '^line', { text,  $vnr,                        dest, }
    send H.fresh_datom '>h',    { level, $vnr: ( VNR.advance $vnr ),  dest, }
    return null

#-----------------------------------------------------------------------------------------------------------
@$blockquotes = ( S ) ->
  ### TAINT ATM also captures closing pointy bracket of multiline tag literals ###
  pattern           = /// ^ (?: (?<mu_1> >+ ) | (?<mu_2> >+ ) \s+ (?<text> .* ) ) $ ///
  prv_was_quote     = false
  $vnr              = null
  dest              = null
  H.register_key S, '<blockquote', { is_block: true, }
  H.register_key S, '>blockquote', { is_block: true, }
  #.........................................................................................................
  return $ { last, }, ( d, send ) =>
    if d is last
      ### TAINT code duplication ###
      if prv_was_quote
        $vnr = VNR.advance $vnr; send H.fresh_datom '>blockquote', { dest, $vnr, }
      return
    #.......................................................................................................
    return send d unless select d, '^line'
    #.......................................................................................................
    unless ( match = d.text.match pattern )?
      ### TAINT code duplication ###
      if prv_was_quote
        $vnr = VNR.advance $vnr; send H.fresh_datom '>blockquote', { dest, $vnr, }
      prv_was_quote = false
      return send d
    #.......................................................................................................
    send stamp d
    markup  = match.groups.mu_1 ? match.groups.mu_2
    text    = match.groups.text ? ''
    $vnr    = VNR.deepen d.$vnr, 0
    unless prv_was_quote
      dest    = d.dest
      $vnr    = VNR.advance $vnr; send H.fresh_datom '<blockquote', {       dest, $vnr, }
      $vnr    = VNR.advance $vnr; send H.fresh_datom '^line',       { text, dest, $vnr, }
    else
      $vnr    = VNR.advance $vnr; send H.fresh_datom '^line',       { text, dest, $vnr, }
    # debug 'µ33344', match.groups, $vnr
    prv_was_quote = true
    # send d
    return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$codeblocks  S
  pipeline.push @$headings    S
  # pipeline.push @$blockquotes S
  return PD.pull pipeline...

