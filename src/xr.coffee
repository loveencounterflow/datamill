





'use strict'


############################################################################################################
{ inspect, }              = require 'util'


#-----------------------------------------------------------------------------------------------------------
@xrpr = ( x ) -> inspect x,
  colors:           true
  breakLength:      Infinity
  maxArrayLength:   Infinity
  depth:            Infinity

#-----------------------------------------------------------------------------------------------------------
@xr = ( x ) -> inspect x,
  colors:           false
  breakLength:      Infinity
  maxArrayLength:   Infinity
  depth:            Infinity


