template = require './gift-card.html'
templateId = require('appendTemplate')('gift-card', template)

PaymentGroupViewModel = require './payment-group.coffee'
Payment = require '../payment-system/payment.coffee'
GiftCardViewModel = require './gift-card-vm.coffee'

class GiftCardPaymentGroupViewModel extends PaymentGroupViewModel
  constructor: (paymentSystemsArray, availableAccountsArray, giftCardsObservableArray) ->
    super(paymentSystemsArray, availableAccountsArray)
    @id = (new Date().getTime()).toString() + Math.random().toString(36).substr(2)
    @template templateId
    @giftCards = giftCardsObservableArray
    @giftCardCode = ko.observable()
    @loadingGiftCard = ko.observable(false)
    @_selectedInstallmentNumber(1)
    @card = ko.observable() # One of paymentData.giftCards
    @availableGiftCards = ko.computed =>
      _.filter @giftCards(), (gc) -> !gc.inUse()

  validateGiftCardCode: (value, element) =>
    validation =
      result: true
      message: ""

    # Se está vazio, retorne e valide OK.
    if value is undefined or value is ""
      validation.applyErrorClass = validation.showErrorMessage = not validation.result
      validation.applySuccessClass = not validation.result
      return validation

    validation.applySuccessClass = validation.result
    validation.applyErrorClass = validation.showErrorMessage = not validation.result
    validation

  cleanValidation: =>  @giftCardCode.validate silent: true  if @giftCardCode.validate

  getPayment: =>
    ps = @paymentSystem()
    return unless @card()
    new Payment(
      paymentSystem: ps.id()
      paymentSystemName: ps.name()
      installments: 1 # Hard coded installments number for integration backwards compatibility
      group: ps.groupName()
      value: @card().value()
      referenceValue: @card().value()
      fields:
        redemptionCode: @card().redemptionCode()
        provider: @card().provider()
        giftCardId: @card().id
    )

  login: =>
    providersURL = window.location.origin + '/api/checkout/pub/gift-cards/providers'
    request = $.ajax
      url: providersURL
      type: 'GET'
      contentType: 'application/json; charset=utf-8'
      dataType: 'json'
    request.done (data) =>
      vtexid.start
        returnUrl: window.location.href
        userEmail: window.clientProfileData.email()
        locale: checkout.locale()
        forceProviders: _.map data, (p) -> p.oauth

  updatePayment: (giftPayment) =>
    @paidValue giftPayment.referenceValue
    @loadingGiftCard false
    cardVM = _.find(@giftCards(), (gc) -> gc.id is giftPayment.id)
    if cardVM
      @card cardVM
      @giftCardCode null

  submitGiftCard: (card) =>
    @loadingGiftCard true
    if card
      @card card
      card.inUse(true)
    else
      @card new GiftCardViewModel(redemptionCode: @giftCardCode(), id: @id, inUse: true, value: @paidValue())
      @giftCards.push @card()

    jqXHR = paymentData.sendAttachment()
    jqXHR.always =>
      @loadingGiftCard false

  removeGiftCard: =>
    @card()?.inUse(false)

module.exports = GiftCardPaymentGroupViewModel
