
class Client extends window.Pokey
    setupFromPage: ->
        @$ = $
        @document = document
        @img = $ 'img'
        @article = $ 'article'
        @h2 = $ 'h2'
        @prev = $ '#prev'
        @next = $ '#next'

        comic = title: document.title
        h = @next.prop 'href'
        if h then comic.next = slugFromUrl h
        h = @prev.prop 'href'
        if h then comic.prev = slugFromUrl h
        cur = History.getState()
        History.replaceState comic, cur.title, cur.url

slugFromUrl = (url) -> url.match(/\/([^\/]*)$/)[1]

headers = {accept: 'application/pokey+json'}
$(document).click (event) ->
    if event.target.tagName.match /^a$/i
        slug = $(event.target).attr 'href'
        if slug and History.enabled
            event.preventDefault()
            pokey.img.attr src: slug + '.jpg'
            $.ajax (
                url: slug
                headers: headers
                timeout: 3000
                success: (json) ->
                    comic = JSON.parse json
                    History.pushState comic, comic.title, slug
                error: ->
                    document.location = slug
            )

pokey = new Client
pokey.setupFromPage()

if History.enabled
    History.Adapter.bind window, 'statechange', ->
        state = History.getState()
        pokey.loadComic slugFromUrl(state.url), state.data
