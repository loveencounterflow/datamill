
'use strict'

#-----------------------------------------------------------------------------------------------------------
@DATOM                    = require 'datom'
@XE                       = @DATOM.new_xemitter()
@NOTIFIER                 = require 'node-notifier'

#-----------------------------------------------------------------------------------------------------------
@_notify_change = ( path ) ->
  settings =
    title:    "File content changed",
    message:  path
    wait:     false
    timeout:  1
  @NOTIFIER.notify settings
  return null

#-----------------------------------------------------------------------------------------------------------
@XE.listen_to '^file-changed', ( d ) => @_notify_change d.doc_file_path
