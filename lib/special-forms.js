// Generated by CoffeeScript 2.4.1
(function() {
  'use strict';
  var $, $async, CND, PD, alert, assign, badge, copy, debug, echo, help, info, is_empty, join, jr, log, rpr, rprx, select, stamp, urge, warn, whisper;

  //###########################################################################################################
  CND = require('cnd');

  rpr = CND.rpr;

  badge = 'DATAMILL/SPECIAL-FORMS';

  log = CND.get_logger('plain', badge);

  info = CND.get_logger('info', badge);

  whisper = CND.get_logger('whisper', badge);

  alert = CND.get_logger('alert', badge);

  debug = CND.get_logger('debug', badge);

  warn = CND.get_logger('warn', badge);

  help = CND.get_logger('help', badge);

  urge = CND.get_logger('urge', badge);

  echo = CND.echo.bind(CND);

  //...........................................................................................................
  PD = require('pipedreams');

  ({$, $async, select, stamp} = PD);

  //...........................................................................................................
  ({jr, copy, is_empty, assign} = CND);

  join = function(x, joiner = '') {
    return x.join(joiner);
  };

  rprx = function(d) {
    var ref;
    return `${d.mark} ${d.type}:: ${jr(d.value)} ${jr((ref = d.stamped) != null ? ref : false)}`;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.active_chr_pattern = /(?:)/u;

  this.active_chrs = new Set();

  //-----------------------------------------------------------------------------------------------------------
  /* thx to https://stackoverflow.com/a/3561711/7568091 */
  this._escape_for_regex = function(text) {
    return text.replace(this._escape_for_regex.pattern, '\\$&');
  };

  this._escape_for_regex.pattern = /[-\/\\^$*+?.()|[\]{}]/g;

  //-----------------------------------------------------------------------------------------------------------
  this.add_active_chrs = function(...chrs) {
    var achrs, chr, i, len;
    for (i = 0, len = chrs.length; i < len; i++) {
      chr = chrs[i];
      if (!((CND.isa_text(chr)) && ((chr.match(/^.$/u)) != null))) {
        throw new Error(`expected single character, got ${rpr(chr)}`);
      }
      this.active_chrs.add(chr);
    }
    achrs = ((function() {
      var ref, results;
      ref = this.active_chrs;
      results = [];
      for (chr of ref) {
        results.push(this._escape_for_regex(chr));
      }
      return results;
    }).call(this)).join('|');
    this.active_chr_pattern = RegExp(`^(?<left>.*?)(?<achrs>(?<achr>${achrs})\\k<achr>*)(?<right>.*)$`);
    // /// (?<!\\) (?<achr> (?<chr> [ \* ` + p ] ) \k<chr>* ) ///
    return null;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.add_active_chrs('<', '&', '*', '`', '^', '_', '=', '-', '+', '𣥒');

  // help @active_chr_pattern

  // debug @_escape_for_regex '*'
  // debug @_escape_for_regex '/'
  // debug @_escape_for_regex '^'
  // debug @_escape_for_regex '\\'
  // debug 'foo-bar'.match new RegExp '[x\\-a]'
  // @add_active_chr '-'; help @active_chr_pattern
  // @add_active_chr '^'; help @active_chr_pattern

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.split_on_first_active_chr = function(text) {
    var match;
    if ((match = text.match(this.active_chr_pattern)) == null) {
      /* If `text` contains an active character, return a POD with the keys `left`, `achr`, and `right`, where
      `left` holds the (possibly empty) text before the first active character, `achr` holds the active
      character itself, and `right` holds the remaining, again possibly empty, text (that may or may not contain
      further active characters). */
      return null;
    }
    return match.groups;
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$split_on_first_active_chr = function(S) {
    return $((d, send) => {
      var achr, achrs, left, parts, right;
      if (!((select(d, '^text')) && (!d.clean))) {
        /* using ad-hoc `clean` attribute to indicate that text does not contain active characters */
        return send(d);
      }
      if ((parts = this.split_on_first_active_chr(d.value)) != null) {
        ({achr, achrs, left, right} = parts);
        send(PD.new_single_event('achr-split', achrs, {achr, left, right}, {
          $: d
        }));
      } else {
        d.clean = true;
        send(d);
      }
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$recycle_untouched_texts = function(S) {
    return $((d, send) => {
      if ((select(d, '^text')) && (!d.clean)) {
        send(PD.R.recycling(d));
      } else if (select(d, '^achr-split')) {
        if (!is_empty(d.left)) {
          send(PD.new_text_event(d.left + d.value, {
            clean: true,
            $: d
          }));
        }
        send(PD.R.recycling(PD.new_text_event(d.right, {
          $: d
        })));
      } else {
        send(d);
      }
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$filter_empty_texts = function(S) {
    return PD.$filter((d) => {
      return !((select(d, '^text')) && (d.value === ''));
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$consolidate_texts = function(S) {
    var buffer;
    buffer = [];
    return $({
      last: null
    }, (d, send) => {
      // debug '93093-1', jr d
      if (d != null) {
        if (select(d, '^text')) {
          buffer.push(d.value);
        } else {
          // whisper '93093-2', buffer
          if (!is_empty(buffer)) {
            send(PD.new_text_event(buffer.join('')));
            buffer.length = 0;
          }
          send(d);
        }
      } else {
        // whisper '93093-3', buffer
        if (!is_empty(buffer)) {
          send(PD.new_text_event(buffer.join('')));
          buffer.length = 0;
        }
      }
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this.$handle_remaining_achrs = function(S) {
    return $((d, send) => {
      var lnr, message, ref, ref1, ref2, text;
      if (select(d, '^achr-split')) {
        lnr = (ref = (ref1 = d.$) != null ? ref1.lnr : void 0) != null ? ref : '?';
        text = ((ref2 = d.$) != null ? ref2.text : void 0) != null ? rpr(d.$.text) : '?';
        message = `unhandled active characters ${rpr(d.value)} on line ${lnr} in ${text}`;
        if (!is_empty(d.left)) {
          send(PD.new_text_event(d.left, {
            clean: true,
            $: d
          }));
        }
        send(PD.new_warning('µ99823', message, d, {
          $: d
        }));
      } else {
        // send PD.new_text_event d.left + d.value + d.right, $: d
        // send d
        send(d);
      }
      return null;
    });
  };

  //-----------------------------------------------------------------------------------------------------------
  this._get_symmetric_achr_transform = function(S, start_stop, name) {
    var closing_key, opening_key, within;
    within = false;
    opening_key = `<${name}`;
    closing_key = `>${name}`;
    //.........................................................................................................
    return $((d, send) => {
      if ((select(d, '^achr-split')) && (d.value === start_stop)) {
        /* using ad-hoc `clean` attribute to indicate that text does not contain active characters */
        send(PD.new_text_event(d.left, {
          clean: true,
          $: d
        }));
        //.....................................................................................................
        if (within) {
          send(PD.new_event(closing_key, null, {
            $: d
          }));
          within = false;
        } else {
          //.....................................................................................................
          send(PD.new_event(opening_key, null, {
            $: d
          }));
          within = true;
        }
        //.....................................................................................................
        send(PD.new_text_event(d.right, {
          $: d
        }));
      } else {
        send(d);
      }
      return null;
    });
  };

  //===========================================================================================================
  /*

  Sources:

  * https://markdown-it.github.io/
  * https://commonmark.org/help/
  * https://www.markdownguide.org/basic-syntax

  Special Forms:

  * *italic*
  * **bold**
  * ***bold italic***—possibly using underscores, e.g. `_**bold italic**_`, `__*bold italic*__`,
    `*__bold italic__*`, ...
  * --strike-- (sometimes using tildes, ~~strike~~)
  * ++ins++ (inserted text, used together with `--strike--`)
  * ==mark== (highlighted, hilite)
  * `code`

   */
  //-----------------------------------------------------------------------------------------------------------
  this.$mark = function(S) {
    return this._get_symmetric_achr_transform(S, '==', 'mark');
  };

  this.$ins = function(S) {
    return this._get_symmetric_achr_transform(S, '++', 'ins');
  };

  this.$strike = function(S) {
    return this._get_symmetric_achr_transform(S, '--', 'strike');
  };

  this.$em_and_strong = function(S) {
    return this._get_symmetric_achr_transform(S, '***', 'em-and-strong');
  };

  this.$strong = function(S) {
    return this._get_symmetric_achr_transform(S, '**', 'strong');
  };

  this.$em = function(S) {
    return this._get_symmetric_achr_transform(S, '*', 'em');
  };

  //===========================================================================================================

  //-----------------------------------------------------------------------------------------------------------
  this.$parse_special_forms = (S) => {
    var byline, bysource, bystream, pipeline, refillable;
    refillable = [];
    bysource = PD.new_refillable_source(refillable, {
      repeat: 5,
      show: true
    });
    byline = [];
    byline.push(bysource);
    byline.push(PD.$show({
      title: '(parse_special_forms bystream)'
    }));
    bystream = PD.pull(...byline);
    //.......................................................................................................
    pipeline = [];
    pipeline.push(PD.$pass());
    /* necessary so `$wye()` doesn't come on top of pipeline */    pipeline.push(PD.$wye(bystream));
    // pipeline.push PD.R.$unwrap_recycled()
    pipeline.push(this.$split_on_first_active_chr(S));
    pipeline.push(this.$mark(S));
    pipeline.push(this.$ins(S));
    pipeline.push(this.$strike(S));
    pipeline.push(this.$em_and_strong(S));
    pipeline.push(this.$em(S));
    pipeline.push(this.$strong(S));
    pipeline.push(this.$recycle_untouched_texts(S));
    pipeline.push(this.$filter_empty_texts(S));
    pipeline.push(this.$handle_remaining_achrs(S));
    // pipeline.push $ { last: PD.symbols.last, }, ( d, send ) ->
    //   debug '33783', '---------------->', d
    //   if d is PD.symbols.last
    //     refillable.push PD.symbols.end
    //   else
    //     send d
    //   return null
    // pipeline.push PD.$watch ( d ) => if ( select d, '~end' ) then source.end()
    // pipeline.push PD.R.$recycle ( d ) -> refillable.push d
    pipeline.push(this.$consolidate_texts(S));
    //.......................................................................................................
    return PD.pull(...pipeline);
  };

}).call(this);

//# sourceMappingURL=special-forms.js.map