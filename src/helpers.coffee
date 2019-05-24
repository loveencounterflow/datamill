

'use strict'



############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'DATAMILL/HELPERS'
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
@cwd_abspath              = CND.cwd_abspath
@cwd_relpath              = CND.cwd_relpath
@here_abspath             = CND.here_abspath
@_drop_extension          = ( path ) -> path[ ... path.length - ( PATH.extname path ).length ]
@project_abspath          = ( P... ) -> CND.here_abspath __dirname, '..', P...


