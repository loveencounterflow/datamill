(function() {
  'use strict';
  var $, $watch, CND, H, PD, SP, VNR, assign, badge, debug, declare, echo, first, help, info, isa, jr, last, rpr, select, size_of, stamp, type_of, types, urge, validate, warn, whisper;

  //###########################################################################################################
  H = require('./helpers');

  CND = require('cnd');

  rpr = CND.rpr;

  badge = H.badge_from_filename(__filename);

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  info = CND.get_logger('info', badge);

  urge = CND.get_logger('urge', badge);

  help = CND.get_logger('help', badge);

  whisper = CND.get_logger('whisper', badge);

  echo = CND.echo.bind(CND);

  ({jr, assign} = CND);

  //...........................................................................................................
  require('./exception-handler');

  first = Symbol('first');

  last = Symbol('last');

  VNR = require('./vnr');

  //...........................................................................................................
  SP = require('steampipes');

  PD = require('pipedreams');

  ({$, $watch} = SP);

  ({select, stamp} = PD);

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, declare, size_of, type_of} = types);

  //-----------------------------------------------------------------------------------------------------------
  this.$initialize = function(S) {
    return $watch({first}, (d) => {
      var db;
      if (d !== first) {
        return null;
      }
      db = S.mirage.dbw;
      db.create_view_dest_changes_backward();
      db.create_view_dest_changes_forward();
      return null;
    });
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$initialize(S));
    return SP.pull(...pipeline);
  };

}).call(this);
