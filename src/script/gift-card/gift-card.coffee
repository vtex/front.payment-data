Payment = require '../payment-system/payment.coffee'

class GiftCardViewModel
  constructor: (json = {}, paymentSystemViewModel) ->
    @id = ko.observable()
    @redemptionCode = ko.observable()
    @value = ko.observable()
    @balance = ko.observable()
    @name = ko.observable()
    @inUse = ko.observable()
    @isSpecialCard = ko.observable()
    @caption = ko.observable()
    @captionClass = ko.observable()
    @provider = ko.observable()
    @paymentSystem = paymentSystemViewModel

    @update json

    @valueLabel = ko.computed =>
      if isNaN(@value()) then null else _.intAsCurrency @value()

    @balanceLabel = ko.computed =>
      if isNaN(@balance()) then null else _.intAsCurrency @balance()

    @friendlyName = ko.computed =>
      if @caption()
        return @caption()
      else if @name()
        return i18n.t('global.'+ @name())

  update: (json) =>
    @id json.id
    @redemptionCode json.redemptionCode
    @value json.value
    @balance json.balance
    @name json.name
    @inUse(json.inUse ? false)
    @isSpecialCard(json.isSpecialCard ? false)
    @caption json.caption
    @captionClass _.spacesToHyphens(json.caption+'').toLowerCase() if json.caption
    @provider json.provider ? window.checkoutConfig.giftCardsProviders()[0].id

  toJSON: =>
    id: @id()
    redemptionCode: @redemptionCode()
    value: @value()
    referenceValue: @value()
    balance: @balance()
    name: @name()
    inUse: @inUse()
    isSpecialCard: @isSpecialCard()
    provider: @provider()

  getPayment: =>
    new Payment(
      paymentSystem: @paymentSystem.id()
      group: @paymentSystem.groupName()
      value: @value()
      referenceValue: @value()
      installments: 1 # Hard coded installments number for integration backwards compatibility
      fields:
        redemptionCode: @redemptionCode()
        provider: @provider()
        giftCardId: @id
    )

module.exports = GiftCardViewModel
