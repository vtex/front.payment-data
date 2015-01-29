template = require './credit-card.html'
templateId = require('appendTemplate')('credit-card', template)

CreditCardPaymentGroupViewModel = require './credit-card.coffee'
class CreditCardCustomPaymentGroupViewModel extends CreditCardPaymentGroupViewModel
  constructor: ->
    super
    @identifier = ko.observable("creditCardCustom")
    @template templateId
    @pgTitle = @name

    @localizedLabel = ko.computed => @name

    # TODO converter para @paymentSystem()
    @selectedPaymentSystemId = ko.observable(@paymentSystems()[0].id())

module.exports = CreditCardCustomPaymentGroupViewModel
