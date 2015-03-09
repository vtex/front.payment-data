appendTemplate = require('appendTemplate')
template = require './gift-card-list.html'
newGiftCardTemplate = require './new-gift-card.html'
appendTemplate('gift-card-list', template)
appendTemplate('new-gift-card', newGiftCardTemplate)

GiftCardViewModel = require './gift-card.coffee'

class GiftCardListViewModel
  constructor: (giftCardPaymentSystem, giftCardsObservableArray) ->
    @paymentSystem = giftCardPaymentSystem
    @giftCards = giftCardsObservableArray
    @giftCardCode = ko.observable()
    @loadingGiftCard = ko.observable(false)
    @giftCardInputVisible = ko.observable(false)
    @selectedProvider = ko.observable(window.checkoutConfig.giftCardsProviders()[0])

    @giftCardProviders = ko.computed =>
      window.checkoutConfig.giftCardsProviders()

    @availableGiftCards = ko.computed =>
      _.filter @giftCards(), (gc) ->
        gc.name() isnt "loyalty-program" and !gc.inUse()

    @availableLoyaltyCards = ko.computed =>
      _.filter @giftCards(), (gc) ->
        gc.name() is "loyalty-program" and !gc.inUse()

    @usedGiftCards = ko.computed =>
      _.filter @giftCards(), (gc) -> gc.inUse()

  giftCardOptionsText: (gc) ->
    if gc.caption?
      return gc.caption
    return gc.id

  showGiftCardInput: =>
    @giftCardInputVisible(true)

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
        forceProviders: _.map @giftCardProviders(), (p) -> p.oauth

  addGiftCard: (card) =>
    return unless card
    cardVM = new GiftCardViewModel(card, @paymentSystem)
    @giftCards.push cardVM
    return cardVM

  submitGiftCard: (card) =>
    giftCardCode = @giftCardCode()
    @loadingGiftCard true
    # Receive via parameter or try to find matching existing card on card list
    cardVM = card or _.find(@giftCards(), (gc) => gc.redemptionCode() is @giftCardCode())
    if cardVM
      cardVM.inUse(true)
    else if (not giftCardCode) or giftCardCode.length is 0
      @loadingGiftCard false
      return
    else
      cardVM = @addGiftCard({redemptionCode: giftCardCode, inUse: true})

    jqXHR = window.paymentData.sendAttachment()
    jqXHR.always =>
      @loadingGiftCard false
      @giftCardCode null
    jqXHR.fail =>
      cardVM.inUse(false)

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
