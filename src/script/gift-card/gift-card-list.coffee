template = require './gift-card-list.html'
require('appendTemplate')('gift-card-list', template)

GiftCardViewModel = require './gift-card.coffee'

class GiftCardListViewModel
  constructor: (giftCardPaymentSystem, giftCardsObservableArray) ->
    @paymentSystem = giftCardPaymentSystem
    @giftCards = giftCardsObservableArray
    @giftCardCode = ko.observable()
    @loadingGiftCard = ko.observable(false)
    @giftCardInputVisible = ko.observable(false)

    @availableGiftCards = ko.computed =>
      _.filter @giftCards(), (gc) ->
        gc.name() isnt "loyalty-program" and !gc.inUse()

    @availableLoyaltyCards = ko.computed =>
      _.filter @giftCards(), (gc) ->
        gc.name() is "loyalty-program" and !gc.inUse()

    @usedGiftCards = ko.computed =>
      _.filter @giftCards(), (gc) -> gc.inUse()

  showGiftCardInput: =>
    @giftCardInputVisible(true)

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

  cleanValidation: => @giftCardCode.validate silent: true  if @giftCardCode.validate

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

  addGiftCard: (card) =>
    return unless card
    @giftCards.push new GiftCardViewModel(card, @paymentSystem)

  submitGiftCard: (card) =>
    @loadingGiftCard true
    # Receive via parameter or try to find matching existing card on card list
    cardVM = card or _.find(@giftCards(), (gc) => gc.redemptionCode() is @giftCardCode())
    if cardVM
      cardVM.inUse(true)
    else
      @addGiftCard({redemptionCode: @giftCardCode(), inUse: true})

    jqXHR = window.paymentData.sendAttachment()
    jqXHR.always =>
      @loadingGiftCard false
      @giftCardCode ''

    @giftCardInputVisible false

  removeGiftCard: (card) =>
    @loadingGiftCard true
    card?.inUse(false)
    jqXHR = window.paymentData.sendAttachment()
    jqXHR.always =>
      @loadingGiftCard false

  getPayments: =>
    _.map @usedGiftCards(), (gc) -> gc.getPayment()

module.exports = GiftCardListViewModel
