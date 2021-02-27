(function() {
  'use strict';
  var $, $async, $watch, CND, H, Md, PD, VNR, assign, badge, debug, declare, echo, first, help, i, info, isa, jr, last, len, md, probe, probes, rpr, select, size_of, stamp, type_of, types, urge, validate, warn, whisper;

  //###########################################################################################################
  H = require('../helpers');

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

  VNR = require('../vnr');

  //...........................................................................................................
  PD = require('steampipes');

  ({$, $watch, $async, select, stamp} = PD.export());

  //...........................................................................................................
  types = require('../types');

  ({isa, validate, declare, size_of, type_of} = types);

  Md = require('markdown-it');

  md = new Md();

  probes = ['***X***', '***X* S**', '**S `*code` *X***', '**S \\`*code` *X***', '**S *X* S**', '**S *X* <ding/> S**', '<div>**S *X* S**</div>', '<div x=foo>**S *X* S**</div>'];

  for (i = 0, len = probes.length; i < len; i++) {
    probe = probes[i];
    // info 'µ33344', ( CND.white rpr probe ), ( CND.yellow md.parse probe )
    info('µ33344', CND.white(rpr(probe)), CND.yellow(md.renderInline(probe)));
  }

}).call(this);

//# sourceMappingURL=parsing-with-markdown-it.js.map