id = 0
class AvailableAccountViewModel
  constructor: (json, paymentSystem) ->
    @id = id++

    @paymentSystem = paymentSystem
    @accountId = ko.observable json.accountId
    @cardNumber = ko.observable json.cardNumber
    @paymentSystemName = ko.observable json.paymentSystemName
    @availableAddresses = ko.observableArray json.availableAddresses
    @groupName = "creditCardPaymentGroup"
    @cardSafetyCodeRequired = paymentSystem.useCvv
    @cardCodeMask = ko.observable("9999")
    @selected = ko.observable()

    @update json, paymentSystem

    @cardNumberLabel = ko.computed =>
      checkout.locale()
      lastNumbers = @cardRemoveAsterisks()
      return "#{@paymentSystemName()} #{i18n.t("paymentData.paymentGroup.creditCard.endingIn")} #{lastNumbers}"

  cardRemoveAsterisks: =>
    @cardNumber().toString().replace(/\*/g, '').trim()

  update: (json) =>
    @accountId json.accountId
    @cardNumber json.cardNumber
    @paymentSystemName json.paymentSystemName
    @availableAddresses json.availableAddresses

module.exports = AvailableAccountViewModel
