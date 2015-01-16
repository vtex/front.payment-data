Installment = require "./installment.coffee"

class PaymentSystem
  constructor: (json) ->
    @id = ko.observable()
    @stringId = ko.observable()
    @name = ko.observable()
    @groupName = ko.observable()
    @description = ko.observable()
    @template = ko.observable()
    @installmentsMap = {}
    @requestedInstallmentValuesArray = []
    @selected = ko.observable()
    # Propriedades de cartão
    @regex = ko.observable()
    @mask = ko.observable()
    @cardCodeRegex = ko.observable()
    @cardCodeMask = ko.observable()
    @weights = ko.observable()
    @requiresAuthentication = ko.observable(false)
    @requiresDocument = ko.observable(false)
    @isCustom = ko.observable()
    # Propriedades para Private Label
    @useBillingAddress = ko.observable()
    @useCardHolderName = ko.observable()
    @useCvv = ko.observable()
    @useExpirationDate = ko.observable()

    @payments = []

    @update(json)

  update: (json) =>
    @description json.description
    @groupName json.groupName
    @id json.id
    @isCustom json.isCustom
    @name json.name
    @requiresAuthentication json.requiresAuthentication
    @requiresDocument json.requiresDocument
    @stringId json.stringId
    @template json.template

    @regex json.validator.regex
    @mask json.validator.mask
    @cardCodeRegex json.validator.cardCodeRegex
    @cardCodeMask json.validator.cardCodeMask
    @weights json.validator.weights

    @useBillingAddress json.validator.useBillingAddress
    @useCardHolderName json.validator.useCardHolderName
    @useCvv json.validator.useCvv
    @useExpirationDate json.validator.useExpirationDate

    return this

  # Recebe um array de installmentOptions desse PaymentSystem
  updateInstallmentsMap: (installmentOptionsArray) =>
    for installmentOption in installmentOptionsArray
      installmentsArray = _(installmentOption.installments).map((i) -> new Installment(i))
      @installmentsMap[installmentOption.value] = installmentsArray

  getInstallmentsForValue: (value) =>
    @installmentsMap[value]

  toJSON: =>
    paymentSystem: @id()
    installments: @installmentsMap

module.exports = PaymentSystem
