module.exports = (templateId, template) ->
  document.body.innerHTML += "<script type='text/html' id='#{templateId}'>#{template}</script>"
  return templateId
