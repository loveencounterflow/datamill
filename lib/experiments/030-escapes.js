(function() {
  'use strict';
  var $, $async, $watch, CND, DATOM, H, SPX, VNR, assign, badge, debug, declare, echo, first, freeze, help, info, is_stamped, isa, jr, last, new_datom, rpr, select, size_of, stamp, thaw, type_of, types, urge, validate, warn, whisper;

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
  first = Symbol('first');

  last = Symbol('last');

  //...........................................................................................................
  SPX = require('./steampipes-extra');

  ({$, $watch, $async} = SPX.export());

  //...........................................................................................................
  DATOM = require('datom');

  ({VNR} = DATOM);

  ({freeze, thaw, new_datom, is_stamped, select, stamp} = DATOM.export());

  //...........................................................................................................
  types = require('./types');

  ({isa, validate, declare, size_of, type_of} = types);

  //-----------------------------------------------------------------------------------------------------------
  this.$code_tag = function(S) {
    var close_tag_pattern, lone_tag_pattern, open_tag_pattern;
    open_tag_pattern = /<(?<tag>[\S]+)\s*>/;
    close_tag_pattern = /<\/(?<tag>[\S]+)\s*>/;
    lone_tag_pattern = /<(?<tag>[\S]+)\s*\/>/;
    return $((d, send) => {
      return send(d);
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$code_sf = function(S) {
    return $((d, send) => {
      return send(d);
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.repeat_phase = false;

  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$code_tag(S));
    pipeline.push(this.$code_sf(S));
    return SPX.pull(...pipeline);
  };

}).call(this);

//# sourceMappingURL=030-escapes.js.map