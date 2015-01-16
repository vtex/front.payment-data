append = require('../common/append-template.coffee')
# Add partial templates to page
templates = ['available-accounts', 'card-fields', 'card-scanner', 'cvv', 'installments', 'new', 'paid-value']
_.each templates, (id) ->
  t = require "./credit-card/#{id}.html"
  append(id, t)

template = require './credit-card.html'
templateId = append('credit-card', template)

PaymentGroupViewModel = require './payment-group.coffee'
CreditCardViewModel = require './credit-card/credit-card-vm.coffee'
CreditCardTotemViewModel = require './credit-card/credit-card-totem-vm.coffee'

debug = require('../common/debug.coffee')('pg-credit')
class CreditCardPaymentGroupViewModel extends PaymentGroupViewModel
  constructor: ->
    super

    @identifier = ko.observable("creditCard")
    @isDebitCard = ko.observable(false)
    @template templateId

    @isCustom = ko.observable @paymentSystems()[0].isCustom()
    @pgTitle = 'paymentData.paymentGroup.' + @identifier() + '.' + @identifier()
    @isEditingSensitiveField = ko.observable()

    # TODO converter para mixin!!!
    @card = if vtex.totem then new CreditCardTotemViewModel(this) else new CreditCardViewModel(this)

  updatePayment: (payment) =>
    card = @card
    # Caso seja um cartão salvo, selecione o com accountId relativo
    if payment.accountId
      card.selectedAvailableAccountId(p.accountId)
      card.showSavedCreditCards()
    # Caso seja um cartão novo, selecione a bandeira
    else if payment.paymentSystem
      ps = _.find(@paymentSystems(), (ps) -> parseInt(ps.id()) is parseInt(payment.paymentSystem))
      if ps isnt @paymentSystem()
        @paymentSystem(ps)
      card.showNewCard()
    else
      @paymentSystem(@paymentSystems()[0])
      card.showNewCard()

    # Atualiza valor interno, pois não queremos trigger as modificações do computed.
    @paidValue(payment.referenceValue)
    @updateInstallments(payment.installments)

  findPaymentSystemByCardNumber: (cardNumber) =>
    cardNumberString = cardNumber + "" # Converte valores undefined ou int para string.
    _.find @paymentSystems(), (item) ->
      regex = new RegExp(item.regex())
      # Ignora cartões sem regex
      item.regex().length > 0 and regex.test(cardNumberString.replace(RegExp(" ", "g"), ""))

  getPayment: (masked) =>
    @card.getPayment(masked)

  validate: (options) =>
    @card.validate(options)

  isValid: (options) =>
    validationResults = @validate(options or giveFocus: true)
    validationResults.length > 0 and _.all validationResults, (val) -> val.result is true

  removeAvailableAccount: (ac) =>
    # TODO send attachment e loading
    @availableAccounts.remove ac

  afterSelected: =>
    @validate(giveFocus:true, showErrorMessage: false, applyErrorClass: false)

module.exports = CreditCardPaymentGroupViewModel
