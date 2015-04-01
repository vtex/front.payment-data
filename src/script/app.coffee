PaymentDataViewModel = require './payment-data.coffee'
paymentDataTemplate = template = require './payment-data.html'
window.vtex.i18n.init()
window.giftCardsProviders = ko.observableArray()
setup = (location, route) ->
  window.paymentData = new PaymentDataViewModel({route: route, location: location});
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
    when 'setup.vtex'
      setup(args[0], args[1])
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
    when 'submit.vtex'
      window.paymentData.submit()
    when 'sendPayments.vtex'
      window.paymentData.sendPayments(args[0])
    when 'authenticatedUser.vtexid'
      $(window).trigger('authenticatedUser.vtexid')

###
Converts events sent by the component to messages to the parent window.
###
origin = '*'
$(window).on "sendAttachment.vtex", (e, attachmentName, attachmentData) ->
  parent.postMessage({"event": "sendAttachment.vtex", "arguments": [attachmentName, attachmentData]}, origin)

$(window).on "componentValidated.vtex", (e, validationResults) ->
  parent.postMessage({"event": "componentValidated.vtex", "arguments": [validationResults]}, origin)

$(window).on "startTransaction.vtex", (e, value, referenceValue, payments) ->
  parent.postMessage({"event": "startTransaction.vtex", "arguments": [value, referenceValue, payments]}, origin)

$(window).on "removeAccount.vtex", (e, accountId) ->
  parent.postMessage({"event": "removeAccount.vtex", "arguments": [accountId]}, origin)

$(window).on "authenticateUser.vtexid", (e, options) ->
  parent.postMessage({"event": "authenticateUser.vtexid", "arguments": [options]}, origin)
