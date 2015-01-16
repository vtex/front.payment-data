id = 0
class AvailableAccountViewModel
  constructor: (json, paymentSystem) ->
    @id = id++

    @accountId = ko.observable json.accountId
    @cardNumber = ko.observable json.cardNumber
    @paymentSystem = ko.observable json.paymentSystem
    @paymentSystemName = ko.observable json.paymentSystemName
    @availableAddresses = ko.observableArray json.availableAddresses
    @cardSafetyCode = ko.observable ''
    @cardSafetyCodeHasFocus = ko.observable()
    @groupName = "creditCardPaymentGroup"

    @cardSafetyCodeRequired = ko.observable if paymentSystem then paymentSystem.useCvv() else false

    @cardCodeMask = ko.observable("9999")
    if paymentSystem and paymentSystem.useCvv()
      @cardCodeMask paymentSystem.cardCodeMask()

    # TODO mover para template
    @cardNumberLabel = ko.computed =>
      checkout.locale()
      lastNumbers = @cardRemoveAsterisks()
      return "#{@paymentSystemName()} #{i18n.t("paymentData.paymentGroup.creditCard.endingIn")} #{lastNumbers}"

  cardRemoveAsterisks: =>
    @cardNumber().toString().replace(/\*/g, "")

  remove: =>
    # TODO receive API parameter
    window.vtexjs.checkout.removeAccountId(@accountId())
    # radio('paymentData.paymentGroup.creditCard.availableAccounts.remove').broadcast(@)

  focusOnCCV: (data) =>
    if @cardSafetyCodeRequired()
      $(".orderform-template.active .step.active #cardCode"+@id).focus()
    return true

  update: (availableAccountJSON) =>
    # TODO

module.exports = AvailableAccountViewModel
