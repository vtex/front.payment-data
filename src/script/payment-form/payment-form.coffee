template = require './payment-form.html'
templateId = require('appendTemplate')('payment-form', template)

CreditCardPaymentGroupViewModel = require '../payment-group/credit-card.coffee'
CreditCardCustomPaymentGroupViewModel = require '../payment-group/credit-card-custom.coffee'
DebitPaymentGroupViewModel = require '../payment-group/debit.coffee'
BankInvoicePaymentGroupViewModel = require '../payment-group/bank-invoice.coffee'
PaymentGroupViewModel = require '../payment-group/payment-group.coffee'

debug = require('debug')('payform')

idCounter = 1
class PaymentFormViewModel
  constructor: (paymentJSON, paymentSystemsObservableArray, availableAccountsObservableArray) ->
    # Assert that data is valid
    if not (ps = paymentSystemsObservableArray())? or ps.length is 0
      throw new Error('Trying to create new PaymentFormViewModel without paymentSystems')

    @id = 'payform' + idCounter++
    @template = templateId
    # The available payment systems which this payment form may choose
    @paymentSystems = paymentSystemsObservableArray
    @availableAccounts = availableAccountsObservableArray
    @paymentGroups = ko.observableArray()

    # UI State
    @validationError = ko.observable(false)
    @active = ko.observable(false)

    @_selectedPaymentGroupViewModel = ko.observable()
    @selectedPaymentGroupViewModel = ko.computed
      read: =>
        @_selectedPaymentGroupViewModel()
      write: (paymentGroupViewModel) =>
        @selectPaymentGroup(paymentGroupViewModel)

    @update(paymentJSON)

    @paymentMethodsCaption = ko.computed =>
      i18n.t("paymentData.paymentMethod")

  selectPaymentGroup: (paymentGroupViewModel) =>
    debug @id, 'selected payment group', paymentGroupViewModel
    currentPaymentGroup = @selectedPaymentGroupViewModel()
    if currentPaymentGroup?.card
      currentPaymentGroup.card?()?.inUse(false)
      currentPaymentGroup.card?(null)
    currentPaidValue = currentPaymentGroup?.paidValue() ? 0
    paymentGroupViewModel?.updatePayment({
      referenceValue: currentPaidValue
    })
    @_selectedPaymentGroupViewModel(paymentGroupViewModel)
    # User changed selected payment group, let API know of this change
    paidValue = paymentGroupViewModel?.paidValue() ? 0
    if paidValue > 0 and paymentGroupViewModel
      $(window).trigger('paymentUpdated.vtex')

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
      when 'debitPaymentGroup'
        return DebitPaymentGroupViewModel
      when 'bankInvoicePaymentGroup'
        return BankInvoicePaymentGroupViewModel
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
      paymentSystemsWithoutGift = _.reject @paymentSystems(), (ps) -> ps.groupName() is 'giftCardPaymentGroup'
      paymentSystemsGroupedByPaymentGroup = _.groupBy paymentSystemsWithoutGift, (ps) -> ps.groupName()
      for groupName, paymentSystems of paymentSystemsGroupedByPaymentGroup
        PaymentGroupViewModelClass = @getPaymentGroupClass(groupName)
        @paymentGroups.push new PaymentGroupViewModelClass(paymentSystems, @availableAccounts)

    # Initialization
    if paymentJSON.paymentSystem? and not @selectedPaymentGroupViewModel()? # No paymentGroup, select according to paymentSystem
      paymentSystem = _.find @paymentSystems(), (ps) => ps.id().toString() is paymentJSON.paymentSystem.toString()
      pg = _.find @paymentGroups(), (pg) -> pg.groupName() is paymentSystem.groupName()
      @_selectedPaymentGroupViewModel(pg)

    @selectedPaymentGroupViewModel()?.updatePayment(paymentJSON)

###
TODO: refactor into component, add child elements to payment-data.html
ko.components.register 'payment-form',
  viewModel: PaymentFormViewModel
  template: template
###

module.exports = PaymentFormViewModel
