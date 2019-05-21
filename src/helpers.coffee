

'use strict'



############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = '明快打字机/HELPERS'
log                       = CND.get_logger 'plain',     badge
debug                     = CND.get_logger 'debug',     badge
info                      = CND.get_logger 'info',      badge
warn                      = CND.get_logger 'warn',      badge
alert                     = CND.get_logger 'alert',     badge
help                      = CND.get_logger 'help',      badge
urge                      = CND.get_logger 'urge',      badge
whisper                   = CND.get_logger 'whisper',   badge
echo                      = CND.echo.bind CND
#...........................................................................................................
PATH 											= require 'path'
#...........................................................................................................
@assign                   = Object.assign
@abspath                  = ( P... ) -> PATH.resolve PATH.join __dirname, '..', P...
@relpath 									= ( P... ) -> PATH.relative process.cwd(), PATH.join P...

#-----------------------------------------------------------------------------------------------------------
@ensure_directory = ( path ) -> new Promise ( resolve, reject ) =>
  ( require 'mkdirp' ) path, ( error ) =>
    throw error if error?
    resolve()


