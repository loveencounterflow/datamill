(function() {
  'use strict';
  var $, $async, $watch, CND, DATOM, H, Md, SPX, TIMETUNNEL, VNR, assign, badge, debug, declare, echo, first, freeze, help, info, is_stamped, isa, jr, last, md, new_datom, rpr, select, size_of, stamp, thaw, type_of, types, urge, validate, warn, whisper;

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

  //...........................................................................................................
  Md = require('markdown-it');

  md = new Md();

  TIMETUNNEL = require('timetunnel');

  //-----------------------------------------------------------------------------------------------------------
  this.$parse = function(S) {
    var guards, intalph, ref, tnl;
    ref = 'mdi/prs';
    guards = 'äöüßp';
    intalph = '0123456789';
    tnl = new TIMETUNNEL.Timetunnel({guards, intalph});
    // tnl.add_tunnel TIMETUNNEL.tunnels.remove_backslash
    // tnl.add_tunnel TIMETUNNEL.tunnels.keep_backslash
    tnl.add_tunnel(TIMETUNNEL.tunnels.htmlish);
    H.register_key(S, '^mktscript', {
      is_block: false
    });
    //.........................................................................................................
    return $((d, send) => {
      var $vnr, modified_text, original_text, text, tunneled_text;
      if (!(select(d, '^hunk'))) {
        return send(d);
      }
      //.......................................................................................................
      original_text = d.text;
      tunneled_text = tnl.hide(original_text);
      modified_text = md.renderInline(tunneled_text);
      text = tnl.reveal(modified_text);
      // info 'µ33344', ( CND.white rpr text ), ( CND.yellow md.parse text )
      // #.......................................................................................................
      // info 'µ33344', ( CND.white  jr original_text )
      // info 'µ33344', ( CND.red    jr tunneled_text )
      // info 'µ33344', ( CND.yellow jr modified_text )
      // info 'µ33344', ( CND.green  jr text )
      // info 'µ33344'
      //.......................................................................................................
      send(stamp(d));
      $vnr = VNR.deepen(d.$vnr, 0);
      send(H.fresh_datom('^mktscript', {text, $vnr, ref}));
      return send;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.repeat_phase = false;

  this.$transform = function(S) {
    var pipeline;
    pipeline = [];
    pipeline.push(this.$parse(S));
    return SPX.pull(...pipeline);
  };

}).call(this);

//# sourceMappingURL=040-markdown-inline.js.map