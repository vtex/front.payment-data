window.console or= {
  log: ->
  warn: ->
  error: ->
}
module.exports = (context = '') ->
  if /vtexlocal|vtexcommercebeta/.test(window.location.host)
    paddedContext = context.slice(0,10) + "          ".split('').splice(0, 10-context.length).join('')
    console.log.bind console, paddedContext + " >"
  else
    ->
