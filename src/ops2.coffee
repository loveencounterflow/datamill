

'use strict'

for node from µ.DOM.select_all '.sparkline'
  { trend           } = node.dataset
  trend               = JSON.parse trend
  svg                 = VOGUE.sparkline_from_trend trend
  µ.DOM.append node, svg
for node from µ.DOM.select_all '.trendchart'
  { trends          } = node.dataset
  trends              = JSON.parse trends
  svg                 = VOGUE.chart_from_trends trends
  µ.DOM.append node, svg


globalThis.socket = io()
socket.emit 'message', { with: 'value', }

