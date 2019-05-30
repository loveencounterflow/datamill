


'use strict'

############################################################################################################
H                         = require '../helpers'
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
require                   '../exception-handler'
first                     = Symbol 'first'
last                      = Symbol 'last'
VNR                       = require '../vnr'
#...........................................................................................................
PD                        = require 'pipedreams'
{ $
  $watch
  $async
  select
  stamp }                 = PD
#...........................................................................................................
types                     = require '../types'
{ isa
  validate
  declare
  size_of
  type_of }               = types

Md = require 'markdown-it'
md = new Md()

probes = [
  '***X***'
  '***X* S**'
  '**S `*code` *X***'
  '**S \\`*code` *X***'
  '**S *X* S**'
  '**S *X* <ding/> S**'
  '<div>**S *X* S**</div>'
  '<div x=foo>**S *X* S**</div>'
  ]

for probe in probes
  # info 'µ33344', ( CND.white rpr probe ), ( CND.yellow md.parse probe )
  info 'µ33344', ( CND.white rpr probe ), ( CND.yellow md.renderInline probe )






