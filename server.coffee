async = require 'async'
config = require './config'
express = require 'express'
jsdom = require 'jsdom'
path = require 'path'
pokey = require './pokey'
twitter = require './twitter'

redis_client = ->
    require('redis').createClient config.REDIS_CONFIG.port

redis = redis_client()

jquery_path = path.join config.WWW_ROOT, 'js', config.JQUERY

class DOM extends pokey.Pokey
    constructor: (@resp) ->
        @after = ''

    setupDOM: (callback) ->
        jsdom.env "<html><body></body></html>", [jquery_path], (errors, window) =>
            if errors
                console.error errors
                @resp.send "Server-side DOM error.", 500
                return
            @$ = window.$
            @document = window.document
            callback.call this, @$, @.document

    setupPage: ->
        $ = @$
        @h1 = $ '<h1/>'
        @img = $ '<img>'
        @prev = $ '<a>Previous</a>'
        @next = $ '<a>Next</a>'
        @nav = $ '<nav><a>Home</a></nav>'
        @article = $('<article/>').append @prev, @img, @next
        $('body').append @h1, @nav, @article
        @after = """<script src="js/#{config.JQUERY}"></script>
                    <script src="js/history.js"></script>
                    <script src="js/pokey.js"></script>
                    <script src="js/client.js"></script>"""

    # workaround
    setTitle: (@title) ->

    render: ->
        """<!doctype html>
           <meta charset="utf-8">
           <title>#{escape_html(@title)}</title>
           <script></script><link rel="stylesheet" href="pokey.css">
           #{@document.body.innerHTML}
           #{@after}"""

escape_html = (s) ->
    s.replace /(&|<|>|")/g, (c) ->
        {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;'}[c]

app = express.createServer()
app.use express.bodyParser()
app.use express.cookieParser()
app.use express.static config.WWW_ROOT
app.use express.session config.SESSION_CONFIG

if config.DEBUG
    app.get '/login', (req, resp) ->
        req.session.username = 'test'
        resp.redirect '/'
else
    app.get '/login', twitter.start_login
    app.get '/confirm', twitter.confirm_login

app.get '/', (req, resp) ->
    redis.lindex 'slugs', -1, (err, latest) ->
        if err then throw err
        if latest
            resp.redirect latest, 303
        else
            resp.send 'No comics!', 404

acceptable = ['text/html', 'application/pokey+json', 'application/json']
negotiate = (req, resp) ->
    mime = false
    if req.headers.accept?
        accept = for m in req.headers.accept.split ','
                     m.split(';', 1)[0]
        for mime in accept
            if mime in acceptable
                return mime
        if '*/*' in accept
            mime = 'text/html'
    else
        mime = 'text/html'
    if not mime
        resp.send "Requested format not supported", 406, {'Content-Type': 'text/plain'}
    mime

app.get /^\/([\w-]+)$/, (req, resp, next) ->
    slug = req.params[0]

    mime = negotiate req, resp
    if not mime
        return

    redis.hgetall "comic:#{slug}", (err, comic) ->
        if err then throw err
        if not comic or not comic.number then return next()

        index = comic.number - 1
        async.parallel {
            prev: (cb) ->
                if index > 0
                    redis.lindex 'slugs', index-1, cb
                else
                    cb null, null
            next: (cb) ->
                redis.lindex 'slugs', index+1, cb
        }, (err, nav) ->
            if err then throw err
            for own k, v of nav
                if v then comic[k] = v
            if mime != 'text/html'
                body = resp.send JSON.stringify(comic), 200, {'Content-Type': mime}
            else
                dom = new DOM resp
                dom.setupDOM ->
                    @setupPage()
                    @loadComic slug, comic
                    resp.send @render()

app.listen config.PORT
