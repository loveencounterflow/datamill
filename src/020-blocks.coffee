




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
@$codeblocks = ( S ) ->
  ### Recognize codeblocks as regions delimited by triple backticks. Possible extensions include
  markup for source code category and double service as pre-formatted blocks. ###
  pattern           = /// ^ (?<backticks> ``` ) $ ///
  within_codeblock  = false
  #.........................................................................................................
  return $ ( d, send ) =>
    return send d unless select d, '^mktscript'
    ### TAINT should send `<codeblock` datom ###
    if ( match = d.text.match pattern )?
      within_codeblock = not within_codeblock
      send stamp d
    else
      if within_codeblock
        send stamp d
        # $vnr  = VNR.new_level d.$vnr, 1
        ### TAINT should somehow make sure properties are OK for a `^literal` ###
        send H.swap_key d, '^literal'
      else
        send d
    # $vnr  = VNR.new_level d.$vnr, 0
    # $vnr  = VNR.advance $vnr; send H.fresh_datom '<codeblock',        { level, $vnr, }
    # $vnr  = VNR.advance $vnr; send H.fresh_datom '>codeblock',        { level, $vnr, }
    return null

#-----------------------------------------------------------------------------------------------------------
@$headings = ( S ) ->
  ### Recognize heading as any line that starts with a `#` (hash). Current behavior is to
  check whether both prv and nxt lines are blank and if not so issue a warning; this detail may change
  in the future. ###
  pattern = /// ^ (?<hashes> \#+ ) (?<text> .* ) $ ///
  #.........................................................................................................
  return $ ( d, send ) =>
    return send d unless select d, '^mktscript'
    return send d unless ( match = d.text.match pattern )?
    prv_line_is_blank = H.previous_line_is_blank  S, d.$vnr
    nxt_line_is_blank = H.next_line_is_blank      S, d.$vnr
    $vnr              = VNR.new_level d.$vnr, 0
    send stamp d
    #.......................................................................................................
    unless prv_line_is_blank
      message = "µ09082 heading should have blank lines above"
      $vnr    = VNR.advance $vnr; send H.fresh_datom '~warning',  { message,      $vnr, }
      $vnr    = VNR.advance $vnr; send H.fresh_datom '^blank',    { linecount: 0, $vnr, }
    #.......................................................................................................
    level = match.groups.hashes.length
    text  = match.groups.text.replace /^\s*(.*?)\s*$/g, '$1' ### TAINT use trim method ###
    $vnr  = VNR.advance $vnr; send H.fresh_datom '<h',         { level, $vnr, }
    $vnr  = VNR.advance $vnr; send H.fresh_datom '^mktscript', { text,  $vnr, }
    $vnr  = VNR.advance $vnr; send H.fresh_datom '>h',         { level, $vnr, }
    #.......................................................................................................
    unless nxt_line_is_blank
      message = "µ09083 heading should have blank lines below"
      $vnr    = VNR.advance $vnr; send H.fresh_datom '~warning',  { message,      $vnr, }
      $vnr    = VNR.advance $vnr; send H.fresh_datom '^blank',    { linecount: 0, $vnr, }
    return null

#-----------------------------------------------------------------------------------------------------------
@$paragraphs = ( S ) ->
  ### TAINT avoid to send `^p` after block-level element ###
  #.........................................................................................................
  return $ ( d, send ) =>
    send d
    # return send d unless select d, '^blank'
    # send stamp d
    # $vnr    = VNR.new_level d.$vnr, 0
    # $vnr    = VNR.advance $vnr; send H.fresh_datom '^p', { blanks: d.linecount, $vnr, }

#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@$transform = ( S ) ->
  pipeline = []
  pipeline.push @$codeblocks  S
  pipeline.push @$headings    S
  pipeline.push @$paragraphs  S
  return PD.pull pipeline...

