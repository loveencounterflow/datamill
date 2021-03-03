




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
first                     = Symbol 'first'
last                      = Symbol 'last'
#...........................................................................................................
SPX                       = require './steampipes-extra'
{ $
  $watch
  $async }                = SPX.export()
#...........................................................................................................
DATOM                     = require 'datom'
{ VNR }                   = DATOM
{ freeze
  thaw
  new_datom
  is_stamped
  select
  stamp }                 = DATOM.export()
#...........................................................................................................
types                     = require './types'
{ isa
  validate
  declare
  size_of
  type_of }               = types
#...........................................................................................................
DM                        = require '..'
{ xr, }                   = require './xr'


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
      return send DATOM.set d, { key: '^literal-blank', ref: 'blk/cdb1', }
    #.......................................................................................................
    return send d unless select d, '^line'
    #.......................................................................................................
    ### line starts or stops codeblock ###
    if ( match = d.text.match pattern )?
      within_codeblock  = not within_codeblock
      dest              = d.dest
      $vnr              = VNR.deepen d.$vnr, 0
      #.....................................................................................................
      if within_codeblock
        send stamp d
        send DATOM.set d, { $vnr, $key: '<codeblock', ref: 'blk/cdb2', } ### TAINT why not use `fresh_datom()`? ###
      #.....................................................................................................
      else
        send stamp d
        send DATOM.set d, { $vnr, $key: '>codeblock', ref: 'blk/cdb3', } ### TAINT why not use `fresh_datom()`? ###
    #.......................................................................................................
    ### line is literal within, unchanged outside of codeblock ###
    else
      if within_codeblock
        d = DATOM.set d, { $key: '^literal', ref: 'blk/cdb4', } ### TAINT why not use `fresh_datom()`? ###
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
    send H.fresh_datom '<h',    { level, $vnr: ( VNR.recede $vnr  ),  dest, ref: 'blk/hd1', }
    send H.fresh_datom '^line', { text,  $vnr,                        dest, ref: 'blk/hd2', }
    send H.fresh_datom '>h',    { level, $vnr: ( VNR.advance $vnr ),  dest, ref: 'blk/hd3', }
    return null

#-----------------------------------------------------------------------------------------------------------
@$blockquotes = ( S ) ->
  ### TAINT ATM also captures closing pointy bracket of multiline tag literals ###
  pattern           = /// ^ (?: (?<mu_1> >+ ) | (?<mu_2> >+ ) \s+ (?<text> .* ) ) $ ///
  within_quote      = false
  first_vnr         = null
  $vnr              = null
  dest              = null
  ### TAINT only register once per pair ###
  H.register_key S, '<blockquote', { is_block: true, has_paragraphs: true, }
  H.register_key S, '>blockquote', { is_block: true, has_paragraphs: true, }
  #.........................................................................................................
  return $ { last, }, ( d, send ) =>
    if d is last
      ### If the previous datom was the last in the document and we're within a blockwuote, close it: ###
      ### TAINT code duplication ###
      if within_quote
        send H.fresh_datom '>blockquote', { dest, $vnr: ( VNR.advance $vnr ), ref: 'blk/bq1', }
        ### TAINT is a single `deepen()` enough to capture proper boundaries? ###
        DM.reprise S, { first_vnr, last_vnr: ( VNR.deepen $vnr ), ref: 'blk/bq2', }
        $vnr      = null
        first_vnr = null
      return null
    #.......................................................................................................
    return send d unless select d, '^line'
    #.......................................................................................................
    unless ( match = d.text.match pattern )?
      #.....................................................................................................
      ### TAINT code duplication ###
      ### If we've found a text that has no blockquote markup, the quote has ended: ###
      if within_quote
        send H.fresh_datom '>blockquote', { dest, $vnr: ( VNR.advance $vnr ), ref: 'blk/bq3', }
        DM.reprise S, { first_vnr, last_vnr: $vnr, ref: 'blk/bq4', }
        $vnr      = null
        first_vnr = null
      #.....................................................................................................
      within_quote = false
      return send d
    #.......................................................................................................
    markup  = match.groups.mu_1 ? match.groups.mu_2
    text    = match.groups.text ? ''
    $vnr    = VNR.deepen d.$vnr, 0
    #.......................................................................................................
    unless within_quote
      dest        = d.dest
      first_vnr   = $vnr
      send H.fresh_datom '<blockquote', {       dest, $vnr: ( VNR.recede $vnr ),  ref: 'blk/bq5', }
      send H.fresh_datom '^line',       { text, dest, $vnr,                       ref: 'blk/bq6', }
    #.......................................................................................................
    else
      dest        = d.dest
      send H.fresh_datom '^line',       { text, dest, $vnr, ref: 'blk/bq7', }
    #.......................................................................................................
    send stamp d
    within_quote = true
    return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$codeblocks  S
  pipeline.push @$headings    S
  pipeline.push @$blockquotes S
  return SPX.pull pipeline...

