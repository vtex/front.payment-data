template = require './payment-form.html'
templateId = require('../common/append-template.coffee')('payment-form', template)

CreditCardPaymentGroupViewModel = require '../payment-group/credit-card.coffee'
CreditCardCustomPaymentGroupViewModel = require '../payment-group/credit-card-custom.coffee'
GiftCardPaymentGroupViewModel = require '../payment-group/gift-card.coffee'
DebitPaymentGroupViewModel = require '../payment-group/debit.coffee'
PaymentGroupViewModel = require '../payment-group/payment-group.coffee'

debug = require('../common/debug.coffee')('payform')

idCounter = 1
class PaymentFormViewModel
  constructor: (paymentJSON, paymentSystemsObservableArray, availableAccountsObservableArray, giftCardsObservableArray) ->
    # Assert that data is valid
    if not (ps = paymentSystemsObservableArray())? or ps.length is 0
      throw new Error('Trying to create new PaymentFormViewModel without paymentSystems')

    @id = 'payform' + idCounter++
    @template = templateId
    # The available payment systems which this payment form may choose
    @paymentSystems = paymentSystemsObservableArray
    @availableAccounts = availableAccountsObservableArray
    @giftCards = giftCardsObservableArray
    @paymentGroups = ko.observableArray()

    # UI State
    @validationError = ko.observable(false)
    @active = ko.observable(false)
    @selectedPaymentGroupViewModel = ko.observable()

    @update(paymentJSON)

  selectPaymentGroup: (paymentGroupViewModel) =>
    debug @id, 'selected payment group', paymentGroupViewModel
    currentPaymentGroup = @selectedPaymentGroupViewModel()
    if currentPaymentGroup?.card
      currentPaymentGroup.card?()?.inUse(false)
    paidValue = currentPaymentGroup?.paidValue() ? 0
    paymentGroupViewModel?.updatePayment({
      referenceValue: paidValue
    })
    @selectedPaymentGroupViewModel(paymentGroupViewModel)
    # User changed selected payment group, let API know of this change
    $(window).trigger('paymentUpdated.vtex') if paidValue > 0 and paymentGroupViewModel

  unselectPaymentGroup: =>
    @selectPaymentGroup(undefined)

  clearValidationError: => @validationError false

  validate: (options) =>
    if (pg = @selectedPaymentGroupViewModel())?
      pg.validate(options)
    else
      return [{result: true}]

  isValid: (options) =>
    validationResults = @validate(options || {giveFocus: true})
    return validationResults.length > 0 && _.all validationResults, (val) =>
      return val.result is true

  getPaymentGroupClass: (groupName) =>
    switch groupName
      when 'creditCardPaymentGroup'
        return CreditCardPaymentGroupViewModel
      when 'debitCardPaymentGroup'
        return CreditCardPaymentGroupViewModel
      when 'giftCardPaymentGroup'
        return GiftCardPaymentGroupViewModel
      when 'debitPaymentGroup'
        return DebitPaymentGroupViewModel
      else
        if groupName.indexOf('customPrivate') isnt -1
          return CreditCardCustomPaymentGroupViewModel
        else
          return PaymentGroupViewModel # generic

  getPayment: (masked) =>
    @selectedPaymentGroupViewModel()?.getPayment(masked)

  requiresAuthentication: =>
    @selectedPaymentGroupViewModel()?.paymentSystem()?.requiresAuthentication()

  update: (paymentJSON) =>
    # Only add payment groups on first run
    if @paymentGroups().length is 0
      paymentSystemsGroupedByPaymentGroup = _.groupBy @paymentSystems(), (ps) -> ps.groupName()
      for groupName, paymentSystems of paymentSystemsGroupedByPaymentGroup
        paymentSystemIdArray = _.map(paymentSystems, (ps) -> parseInt(ps.id()))
        availableAccountsForPaymentGroup = _.filter @availableAccounts(), (aa) ->
          paymentSystemId = parseInt(aa.paymentSystem())
          paymentSystemId in paymentSystemIdArray
        PaymentGroupViewModelClass = @getPaymentGroupClass(groupName)
        @paymentGroups.push new PaymentGroupViewModelClass(paymentSystems, availableAccountsForPaymentGroup, @giftCards)

    # Initialization
    if paymentJSON.paymentSystem? and not @selectedPaymentGroupViewModel()? # No paymentGroup, select according to paymentSystem
      paymentSystem = _.find @paymentSystems(), (ps) => ps.id().toString() is paymentJSON.paymentSystem.toString()
      pg = _.find @paymentGroups(), (pg) -> pg.groupName() is paymentSystem.groupName()
      @selectedPaymentGroupViewModel(pg)

    @selectedPaymentGroupViewModel()?.updatePayment(paymentJSON)

###
TODO: refactor into component, add child elements to payment-data.html
ko.components.register 'payment-form',
  viewModel: PaymentFormViewModel
  template: template
###

module.exports = PaymentFormViewModel
