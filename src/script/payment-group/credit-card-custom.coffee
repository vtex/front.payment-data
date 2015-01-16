template = require './credit-card.html'
templateId = require('../common/append-template.coffee')('credit-card', template)

CreditCardPaymentGroupViewModel = require './credit-card.coffee'
class CreditCardCustomPaymentGroupViewModel extends CreditCardPaymentGroupViewModel
  constructor: ->
    super
    @identifier = ko.observable("creditCardCustom")
    @template templateId
    @pgTitle = @name

    @localizedLabel = ko.computed => @name

    @selectedPaymentSystemId = ko.observable(@paymentSystems()[0].id())

  afterSelected: (wasSelectedBefore) =>
    return if wasSelectedBefore
    @card.setupCustomCard(@paymentSystem())
    $('.payment-card-number input').focus()

  afterRenderGroup: =>
    $('.orderform-template-holder').i18n()
    @card.cardNumber.validate(silent: true) if @card.cardNumber.validate

module.exports = CreditCardCustomPaymentGroupViewModel
