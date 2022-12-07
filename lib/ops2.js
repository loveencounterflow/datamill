(function() {
  'use strict';
  var node, ref, ref1, svg, trend, trends;

  ref = µ.DOM.select_all('.sparkline');
  for (node of ref) {
    ({trend} = node.dataset);
    trend = JSON.parse(trend);
    svg = VOGUE.sparkline_from_trend(trend);
    µ.DOM.append(node, svg);
  }

  ref1 = µ.DOM.select_all('.trendchart');
  for (node of ref1) {
    ({trends} = node.dataset);
    trends = JSON.parse(trends);
    svg = VOGUE.chart_from_trends(trends);
    µ.DOM.append(node, svg);
  }

  globalThis.socket = io();

  socket.emit('message', {
    with: 'value'
  });

}).call(this);

//# sourceMappingURL=ops2.js.map