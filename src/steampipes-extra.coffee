

SP                        = require 'steampipes'
DATOM                     = require 'datom'


provide_extras = ->
  #-----------------------------------------------------------------------------------------------------------
  @$group_by = ( grouper ) ->
    ### TAINT, simplify, generalize, implement as standard transform `$group_by()` ###
    prv_name  = null
    buffer    = null
    send      = null
    last      = Symbol 'last'
    #.........................................................................................................
    flush = =>
      return unless buffer? and buffer.length > 0
      send DATOM.new_datom '^group', { name: prv_name, value: buffer[ .. ], }
      buffer = null
    #.........................................................................................................
    return @$ { last, }, ( d, send_ ) =>
      send = send_
      return flush() if d is last
      #.......................................................................................................
      if ( name = grouper d ) is prv_name
        return buffer.push d
      #.......................................................................................................
      flush()
      prv_name  = name
      buffer   ?= []
      buffer.push d
      return null
  #-----------------------------------------------------------------------------------------------------------
  @$mark_position = ->
    ### Turns values into objects `{ first, last, value, }` where `value` is the original value and `first`
    and `last` are booleans that indicate position of value in the stream. ###
    # last      = @_symbols.last
    last      = Symbol 'last'
    is_first  = true
    prv       = []
    return @$ { last, }, ( d, send ) =>
      if ( d is last ) and prv.length > 0
        if prv.length > 0
          send { is_first, is_last: true, d: prv.pop(), }
        return null
      if prv.length > 0
        send { is_first, is_last: false, d: prv.pop(), }
        is_first = false
      prv.push d
      return null

  #-----------------------------------------------------------------------------------------------------------
  @mark_position = ( transform ) -> @pull @$mark_position(), transform

provide_extras.apply SP
module.exports = SP

