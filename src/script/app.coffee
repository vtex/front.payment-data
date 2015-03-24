PaymentDataViewModel = require './payment-data.coffee'
paymentDataTemplate = template = require './payment-data.html'
window.vtex.i18n.init()
window.giftCardsProviders = ko.observableArray()
window.paymentData = new PaymentDataViewModel({route: 'payment'});
ko.components.register('payment-data', {
  viewModel: {instance: window.paymentData},
  template: paymentDataTemplate
})
ko.applyBindings(window.paymentData)

###
Listens to events by the parent window
###
$(window).on "message onmessage", (e) ->
  console.log 'Payment data received message', e.originalEvent?.data
  event = e.originalEvent.data.event
  args = e.originalEvent.data.arguments
  switch event
    when 'orderFormUpdated.vtex'
      $(window).trigger 'orderFormUpdated.vtex', args
    when 'giftCardProviders.vtex'
      window.giftCardsProviders args[0]
    when 'enable.vtex'
      window.paymentData.enable()
    when 'disable.vtex'
      window.paymentData.exit()
    when 'useCardScanner.vtex'
      window.paymentData.useCardScanner(true)
    when 'authenticatedUser.vtexid'
      $(window).trigger('authenticatedUser.vtexid')

###
Converts events sent by the component to messages to the parent window.
###
origin = 'http://' + window.location.host
$(window).on "sendAttachment.vtex", (e, attachmentName, attachmentData) ->
  parent.postMessage({"event": "sendAttachment.vtex", "arguments": [attachmentName, attachmentData]}, origin)

$(window).on "submitPayments.vtex", (e, value, referenceValue, payments) ->
  parent.postMessage({"event": "submitPayments.vtex", "arguments": [value, referenceValue, payments]}, origin)

$(window).on "removeAccount.vtex", (e, accountId) ->
  parent.postMessage({"event": "removeAccount.vtex", "arguments": [accountId]}, origin)

$(window).on "authenticateUser.vtexid", (e, options) ->
  parent.postMessage({"event": "authenticateUser.vtexid", "arguments": [options]}, origin)

###
Signals that the iframe is ready to start receiving messages
###
parent.postMessage("ready", origin)
