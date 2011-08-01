class Pokey
    loadComic: (slug, comic) ->
        @img.attr 'src', slug + '.jpg'
        @h2.text comic.title
        @document.title = comic.title
        if comic.prev then @prev.attr href: comic.prev else @prev.removeAttr 'href'
        if comic.next then @next.attr href: comic.next else @next.removeAttr 'href'

exports ?= window
exports.Pokey = Pokey
