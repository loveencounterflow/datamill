



'use strict'


############################################################################################################
require                   '../exception-handler'
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'INTERPLOT/DEMO-PUPPETEER'
debug                     = CND.get_logger 'debug',     badge
alert                     = CND.get_logger 'alert',     badge
whisper                   = CND.get_logger 'whisper',   badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
urge                      = CND.get_logger 'urge',      badge
info                      = CND.get_logger 'info',      badge
PATH                      = require 'path'
FS                        = require 'fs'
{ jr, }                   = CND
assign                    = Object.assign
join_path                 = ( P... ) -> PATH.resolve PATH.join P...
#...........................................................................................................
isa                       = require 'intertype'
PD                        = require 'pipedreams'
{ $
  async }                 = PD
#...........................................................................................................
after                     = ( dts, f ) -> setTimeout f, dts * 1000
sleep                     = ( dts ) -> new Promise ( done ) -> after dts, done
page_html_path            = PATH.resolve PATH.join __dirname, '../../../public/main.html'
PUPPETEER                 = require 'puppeteer'

#-----------------------------------------------------------------------------------------------------------
settings =
  has_error:    false
  close:
    on_finish:  true
    on_error:   false
  puppeteer:
    headless:           false
    headless:           true
    # defaultViweport:
    #   deviceScaleFactor:  0.5
    args: [
      '--disable-infobars' # hide 'Chrome is being controlled by ...'
      '--no-first-run'
      # '--incognito'
      # process.env.NODE_ENV === "production" ? "--kiosk" : null
      '--allow-file-access-from-files'
      '--no-sandbox'
      '--disable-setuid-sandbox'
      # '--start-fullscreen'
      '--start-maximized'
      ]
  screenshot:
    path:             PATH.resolve __dirname, '../.cache/chart.png'
    omitBackground:   false
    # fullPage:         true
    fullPage:         false
    type:             'png'
    # clip:
    #   x:                0
    #   y:                0
    #   width:            500
    #   height:           500

#-----------------------------------------------------------------------------------------------------------
echo_browser_console = ( c ) =>
  unless c._type in [ 'log', ]
    whisper ( rpr c )[ .. 100 ]
  if c._type is 'error'
    settings.has_error = true
    warn 'µ37763', 'console:', c._text
    if ( settings.close?.on_error ? false )
      after 3, => process.exit 1
    # throw new Error c._text
  #.........................................................................................................
  else
    info 'µ37763', 'console:', c._text
  return null

#-----------------------------------------------------------------------------------------------------------
get_page = ( browser ) ->
  if isa.empty ( pages = await browser.pages() )
    urge "µ29923-2 new page";           R = await browser.newPage()
  else
    urge "µ29923-2 use existing page";  R = pages[ 0 ]
  return R

#-----------------------------------------------------------------------------------------------------------
take_screenshot = ( page ) ->
  screenshot_written = false
  if settings.screenshot.fullPage
    urge "µ29923-6 take screenshot";    await page.screenshot settings.screenshot
    screenshot_written = true
  else
    urge "µ29923-5 page goto";          chart_dom = await page.$ '#chart'
    if chart_dom?
      urge "µ29923-6 take screenshot";    await chart_dom.screenshot settings.screenshot
      screenshot_written = true
    else
      warn "unable to take screenshot: DOM element not found"
  if screenshot_written
    help "output written to #{PATH.relative process.cwd(), settings.screenshot.path}"
  return null

#-----------------------------------------------------------------------------------------------------------
demo_2 = ->
  # Set up browser and page.
  urge "^interplot/gpdf@4198-1 launching browser";  browser = await PUPPETEER.launch settings.puppeteer
  page = await get_page browser
  page.setViewport { width: 1200, height: 1200, }
  page.on 'error', ( error ) => throw error
  page.on 'console', echo_browser_console
  # urge "^interplot/gpdf@4198-2 page goto";          await page.goto 'file:///home/flow/io/interplot/public/main.html'
  # urge "^interplot/gpdf@4198-3 page goto";          await page.goto 'https://de.wikipedia.org/wiki/Berlin'
  urge "^interplot/gpdf@4198-3 page goto";          await page.goto 'http://localhost:8080/slugs'
  # urge "^interplot/gpdf@4198-3 page goto";          await page.goto 'http://localhost:8080/slugs', { waitUntil: "networkidle2" }
  # urge "^interplot/gpdf@4198-4 page goto";          await page.goto 'http://google.com'
  # urge "^interplot/gpdf@4198-5 waitForSelector";    await page.waitForSelector '#chart'
  # urge "^interplot/gpdf@4198-6 waitForSelector";    await page.waitForSelector '#chart_ready', { timeout: 600e3, }
  urge "^interplot/gpdf@4198-6 waitForSelector";    await page.waitForSelector '#page-ready', { timeout: 600e3, }
  #.........................................................................................................
  if settings.puppeteer.headless
    urge "^interplot/gpdf@4198-7 wait for PDF";       pdf = await page.pdf { format: 'A4', }
    debug '^^interplot/gpdf@4198-7^', pdf
    path = '/tmp/test.pdf'
    ( require 'fs' ).writeFileSync path, pdf
    info "ouput written to #{path}"
  #.........................................................................................................
  if ( settings.close?auto ? false ) and ( not settings.has_error ? false )
    urge "^interplot/gpdf@4198-8 close"; await browser.close()
  urge "^interplot/gpdf@4198-9 done"



############################################################################################################
unless module.parent?
  do =>
    # await sleep 5
    await demo_2()
    help 'ok'
    if settings.puppeteer.headless
      process.exit 0 ### needed? ###



