append = require('appendTemplate')
# Add partial templates to page
templates = ['available-accounts', 'card-fields', 'card-scanner', 'cvv', 'installments', 'new', 'paid-value', 'card-flags-installments']
_.each templates, (id) ->
  t = require "./credit-card/#{id}.html"
  append(id, t)

template = require './credit-card.html'
templateId = append('credit-card', template)

PaymentGroupViewModel = require './payment-group.coffee'
CreditCardViewModel = require './credit-card/credit-card-vm.coffee'
CreditCardTotemViewModel = require './credit-card/credit-card-totem-vm.coffee'

debug = require('debug')('pg-credit')
class CreditCardPaymentGroupViewModel extends PaymentGroupViewModel
  constructor: ->
    super

    @identifier = ko.observable("creditCard")
    @isDebitCard = ko.observable(false)
    @template templateId

    @isCustom = ko.observable @paymentSystems()[0].isCustom()
    @pgTitle = 'paymentData.paymentGroup.' + @identifier() + '.' + @identifier()

    # TODO converter para mixin!!!
    @card = if vtex.totem then new CreditCardTotemViewModel(this) else new CreditCardViewModel(this)

  updatePayment: (payment) =>
    super
    unusedAvailableAccounts = @unusedAvailableAccounts.peek()
    # If payment from API has accountId OR it's a new payment and there's unused available accounts
    if payment?.accountId or (unusedAvailableAccounts.length > 0 and not payment?.paymentSystem)
      @card.showSavedCreditCards()
    else
      @card.showNewCard()

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

module.exports = CreditCardPaymentGroupViewModel
