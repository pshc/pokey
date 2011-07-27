config = require './config'
oauth = require 'oauth'

request_token_url = "https://api.twitter.com/oauth/request_token"
access_token_url = "https://api.twitter.com/oauth/access_token"
authorize_url = "https://api.twitter.com/oauth/authorize"

oa = new oauth.OAuth request_token_url, access_token_url, config.TWITTER_CONSUMER_KEY, config.TWITTER_CONSUMER_SECRET, '1.0', config.TWITTER_CALLBACK_URL, 'HMAC-SHA1'

exports.start_login = (req, resp) ->
  oa.getOAuthRequestToken (err, token, secret, results) ->
    if err
      console.error err
      resp.send 500, 'OAuth error.'
      return
    # Ought to expire this.
    req.session["oauth:#{token}"] = secret
    resp.redirect "#{authorize_url}?oauth_token=#{token}", 303

exports.confirm_login = (req, resp) ->
  token = req.query.oauth_token
  verifier = req.query.oauth_verifier
  if not token or not verifier
    resp.redirect '/'
    return
  key = "oauth:#{token}"
  secret = req.session[key]
  if not secret
    resp.send 401, 'No login cookie. Try again.'
    return
  delete req.session[key]
  oa.getOAuthAccessToken token, secret, verifier, (err, access_token, access_token_secret, results) ->
    if err
      if parseInt err.statusCode == 401
        resp.send 401, 'Permission failure.'
      else
        resp.send 500, 'OAuth error.'
        console.error err
      return
    req.session.username = results.screen_name
    resp.redirect '/', 303
