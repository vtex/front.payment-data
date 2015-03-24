orderFormTextArea = $('#orderform')
providersTextArea = $('#providers')
iframe = $('iframe')
$.getJSON '/front.payment-data/mock/orderform-2.json', (orderForm) ->
  orderFormTextArea.val(JSON.stringify(orderForm, null, 2))

$.getJSON '/front.payment-data/mock/providers.json', (providers) ->
  providersTextArea.val(JSON.stringify(providers, null, 2))

$('#desktop').click -> iframe.removeClass('tablet mobile'); window.location.hash = 'desktop'
$('#tablet').click -> iframe.removeClass('mobile').addClass('tablet'); window.location.hash = 'table'
$('#mobile').click -> iframe.removeClass('tablet').addClass('mobile'); window.location.hash = 'mobile'

if window.location.hash
  $(window.location.hash).click() #Lulz using hash for id

###
A sample implementation of an app using the payment data iframe API
###
sendOrderForm = ->
  try
    iframe[0].contentWindow.postMessage({event: 'giftCardProviders.vtex', arguments: [JSON.parse(providersTextArea.val())]}, 'http://' + window.location.host)
    iframe[0].contentWindow.postMessage({event: 'orderFormUpdated.vtex', arguments: [JSON.parse(orderFormTextArea.val())]}, 'http://' + window.location.host)
    iframe[0].contentWindow.postMessage({event: 'enable.vtex', arguments: []}, 'http://' + window.location.host)
  catch e
    console.log e
  return false

$('form#message button').click sendOrderForm

$(window).on "authenticatedUser.vtexid", ->
  iframe[0].contentWindow.postMessage({event: 'authenticatedUser.vtexid', arguments: []})

$(window).on "message onmessage", (e) ->
  console.log 'Received message', e.originalEvent?.data
  event = e.originalEvent.data.event
  args = e.originalEvent.data.arguments
  switch event
    when "sendAttachment.vtex"
      # window.vtexjs.checkout.sendAttachment(arguments[0], arguments[1])
      console.log 'sendAttachment', args
    when "submitPayments.vtex"
      # value = arguments[0]
      # referenceValue = arguments[1]
      # window.vtexjs.checkout.startTransaction(value, referenceValue, interestValue, ...)
      console.log 'submitPayments', args
    when "removeAccount.vtex"
      # window.vtexjs.checkout.removeAccountId(arguments[0])
      console.log 'submitPayments', args
    when "authenticateUser.vtexid"
      # window.vtexid.start(arguments[0])
      console.log 'authenticateUser', args

# Initial load
$(window).on "message onmessage", (e) ->
  if e.originalEvent.data is 'ready'
    sendOrderForm()
