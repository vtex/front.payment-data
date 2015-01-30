template = require './payment-data.html'
Module = require 'Module'
Translatable = require 'Translatable'
Step = require 'Step'
Routable = require 'Routable'
PaymentFormViewModel = require './payment-form/payment-form.coffee'
PaymentSystem = require './payment-system/payment-system.coffee'
AvailableAccountViewModel = require './payment-group/credit-card/available-account-vm.coffee'
GiftCardViewModel = require './payment-group/gift-card-vm.coffee'

debug = require('debug')('payment')

class PaymentDataViewModel extends Module
  @include Translatable
  @include Routable
  @include Step

  constructor: (params) ->
    @id = 'paymentData'
    @route = params.route

    @setupRouter()

    @wannaChangePaymentValue = ko.observable(false)
    @paymentSystems = ko.observableArray([])
    @availableAccounts = ko.observableArray([])
    @giftCards = ko.observableArray([])
    @paymentForms = ko.observableArray([])
    @selectedPaymentFormViewModel = ko.observable()
    @giftCardMessages = ko.observableArray([])
    @validationError = ko.observable(false)

    @totalToPay = ko.computed =>
      window.checkout.total?() ? window.summary.total()

    @totalPaid = ko.computed =>
      payments = @getAllPayments(true)
      _.reduce(payments, ((v, p) -> v + p.referenceValue), 0)

    @totalPaidDifference = ko.computed =>
      @totalToPay() - @totalPaid()

    @totalIsFree = ko.computed => @totalToPay() is 0

    @showPaymentOptions = ko.computed =>
      return @active() and !@totalIsFree()

    @isScanningCard = ko.observable(false)

    @showPaymentGroupSelector = ko.computed =>
      paymentForms = @paymentForms()
      selectedPaymentForm = @selectedPaymentFormViewModel()
      selectedPaymentGroup = selectedPaymentForm?.selectedPaymentGroupViewModel()
      if paymentForms.length is 1 or not selectedPaymentGroup?
        return true
      else
        return false

    $(window).on 'orderFormUpdated.vtex', (e, orderForm) =>
      return unless orderForm.paymentData
      debug 'Parsing payment data from event'
      @update(orderForm)

    $(window).on 'paidValueUpdated.vtex', @paidValueUpdatedHandler

    $(window).on 'paymentUpdated.vtex', _.debounce(@paymentUpdatedHandler, 100)

  enter: =>
    @visited(true)
    @active(true)

  exit: =>
    @active(false)

  enable: =>
    @visited true
    @active true
    @isValid({giveFocus: true, showErrorMessage: false, applyErrorClass: false})
    if window.Mobile
      Mobile.SwipeCardReaderIsConnected()
    $(window).trigger('checkout.fixCart')

  addPaymentForm: =>
    # Don't add a payment unless all existing payments are valid
    return unless _.all @validatePaymentForms(giveFocus: true, showErrorMessage: true, applyErrorClass: false), (r) -> r.result

    diff = @totalPaidDifference()
    newPayment =
      referenceValue: if diff > 0 then diff else 0
      installment: 1

    paymentForm = new PaymentFormViewModel(newPayment, @paymentSystems, @availableAccounts, @giftCards)
    @paymentForms.push paymentForm
    @selectPaymentForm paymentForm

  removePaymentForm: (paymentForm) =>
    debug 'remove payment', paymentForm
    if paymentForm is @selectedPaymentFormViewModel()
      indexOfPaymentForm = _.indexOf(@paymentForms(), paymentForm)
      newPaymentFormIndex = Math.abs(indexOfPaymentForm - 1) # if 0, select 1
      @selectedPaymentFormViewModel(@paymentForms()[newPaymentFormIndex])
    @paymentForms.remove(paymentForm)
    paymentForm.selectedPaymentGroupViewModel()?.removeGiftCard?()
    paymentForm.selectedPaymentGroupViewModel()?.selectedAvailableAccount()?.selected(false)
    @sendAttachment()
    return false

  selectPaymentForm: (paymentFormViewModel) =>
    # Don't select a payment unless current is valid
    return unless _.all @selectedPaymentFormViewModel()?.validate(giveFocus: true, showErrorMessage: true, applyErrorClass: false), (r) -> r.result

    debug 'select payment', paymentFormViewModel
    @selectedPaymentFormViewModel(paymentFormViewModel)

  clearValidationError: => @validationError false

  getAllPayments: (masked) =>
    _.chain(@paymentForms()).map((pf) -> pf.getPayment(masked)).compact().value()

  # Sends payments to checkout API to decide if there are installments or benefits available
  sendAttachment: =>
    payments = @getAllPayments(true)
    paymentAttachment =
      payments: _.filter payments, (p) -> p.group isnt 'giftCardPaymentGroup'
      giftCards: _.map @giftCards(), (g) -> g.toJSON()

    window.vtexjs.checkout.sendAttachment('paymentData', paymentAttachment)

  paidValueUpdatedHandler: (e, data) =>
    totalToPay = @totalToPay()
    paymentForms = _.filter @paymentForms(), (p) -> p.selectedPaymentGroupViewModel()?.groupName() isnt 'giftCardPaymentGroup'
    if data.paidValue and data.paymentGroupId and paymentForms.length is 2
      otherPaymentForm = _.find(paymentForms, (pf) -> pf.selectedPaymentGroupViewModel()?.id isnt data.paymentGroupId)
      remainingValue = totalToPay - data.paidValue
      if otherPaymentForm and otherPaymentForm.selectedPaymentGroupViewModel()?.paidValue() isnt remainingValue # do nothing if other payment is correct
        otherPaymentForm.selectedPaymentGroupViewModel()?.paidValue(remainingValue)

  paymentUpdatedHandler: =>
    # If we are not active, this update can be ignored because the API
    # will return all payment data correctly once the current API call ends
    return if not @active()

    # Don't send any payments if there aren't items on the cart.
    return if window.cart.items.peek().length is 0

    @sendAttachment()

  updateInterestTotalizer: =>
    payments = @getAllPayments(true)

    interest = 0
    for payment in payments
      if payment.value and payment.referenceValue
        interest += payment.value - payment.referenceValue

    $(window).trigger('checkout.totalizers.interest', [interest])

  # @return {string} O array de Payments serializados como JSON
  paymentsArrayJSON: => return JSON.stringify @getAllPayments()

  validatePaymentForms: (options) =>
    _.chain(@paymentForms()).map((pf) -> pf.validate(options)).flatten().value()

  validatePaidValue: =>
    totalPaidByPaymentForms = _.reduce(@getAllPayments(true), ((memo, p)-> memo + p.referenceValue), 0)
    if totalPaidByPaymentForms < @totalToPay()
      totalPaidValidationResult = { result: false, message: i18n.t('paymentData.paymentsValueInsufficient') }
    else if totalPaidByPaymentForms > @totalToPay()
      totalPaidValidationResult = { result: false, message: i18n.t('paymentData.paymentsValueExceeding') }
    else
      totalPaidValidationResult = { result: true }

    return [totalPaidValidationResult]

  validate: (options) =>
    return @validatePaymentForms(options).concat(@validatePaidValue(options))

  isValid: (options) =>
    validationResults = @validate(options || {giveFocus: true})
    result = validationResults.length > 0 && _.all validationResults, (val) => return val.result is true
    return result

  # Inicia uma transação com o gateway e envia todos os pagamentos.
  submit: =>
    if @isScanningCard() then return

    # Não inicie o submit enquanto estiver inválido - a menos que seja gratuito.
    if !@totalIsFree() && !@isValid()
      @validationError true
      return false

    if not @active()
      return false

    paymentSystemRequiresAuthentication = _.any @paymentForms(), (pf) -> pf.requiresAuthentication()
    authenticated = checkout.loggedIn() or checkout.userType() is 'callCenterOperator'
    if paymentSystemRequiresAuthentication and not authenticated
      return @authenticateBeforePaying(@submit)

    payments = @getAllPayments()
    value = _.reduce(payments, ((memo, p)-> memo + p.value), 0)
    referenceValue = _.reduce(payments, ((memo, p)-> memo + p.referenceValue), 0)
    @loading true
    $(window).trigger('checkout.paymentData.submit', [value, referenceValue, payments])
    return false

  authenticateBeforePaying: (callback) =>
    vtexid.start
      returnUrl: window.location.href
      userEmail: window.clientProfileData.email()
      locale: window.checkout.locale()
      title: i18n.t('paymentData.requiresAuthentication')
      $(window).one 'authenticatedUser.vtexid', ->
        oldEmail = window.clientProfileData.email()
        $(window).trigger('startLoading.vtex')
        xhr = vtexjs.checkout.getOrderForm()
        xhr.then ->
          if oldEmail is window.vtexjs.checkout.orderForm.clientProfileData.email
            callback()
        xhr.always ->
          $(window).trigger('stopLoading.vtex')
    return false

  updatePaymentSystems: (paymentData) =>
    # Adiciona ou atualiza todos os paymentSystems
    for psJson, i in paymentData.paymentSystems
      ps = _(@paymentSystems()).find (eps) =>
        return eps.id() is parseInt(psJson.id)

      if ps
        ps.update psJson
      else
        ps = new PaymentSystem(psJson)
        @paymentSystems.push(ps)

      # Atualiza os installmentOptions desse paymentSystem
      installmentsOptionsForPaymentSystem = _.filter paymentData.installmentOptions, (io) ->
        ps.id() is parseInt(io.paymentSystem)

      ps.updateInstallmentsMap(installmentsOptionsForPaymentSystem)

  updateAvailableAccounts: (paymentData) =>
    for availableAccountJSON, i in paymentData.availableAccounts
      availableAccount = _(@availableAccounts()).find (account) =>
        return account.accountId() is availableAccountJSON.accountId

      paymentSystem = _.find @paymentSystems(), (ps) -> parseInt(ps.id()) is parseInt(availableAccountJSON.paymentSystem)

      if availableAccount
        availableAccount.update availableAccountJSON, paymentSystem
      else
        availableAccount = new AvailableAccountViewModel(availableAccountJSON, paymentSystem)
        @availableAccounts.push(availableAccount)

  updateGiftCards: (paymentData) =>
    if paymentData.giftCards.length != @giftCards().length
      @giftCards.removeAll()

    for giftCardJSON, i in paymentData.giftCards
      giftCard = _(@giftCards()).find (gc) =>
        return gc.id.toString() is giftCardJSON.id.toString()

      if giftCard
        giftCard.update giftCardJSON
      else
        giftCard = new GiftCardViewModel(giftCardJSON)
        @giftCards.push(giftCard)

  updatePaymentForms: (payments, giftPayments) =>
    paymentForms = _.filter @paymentForms(), (p) -> p.selectedPaymentGroupViewModel()?.groupName() isnt 'giftCardPaymentGroup'
    giftPaymentForms = _.filter @paymentForms(), (p) -> p.selectedPaymentGroupViewModel()?.groupName() is 'giftCardPaymentGroup'

    # If we have less payments now then before, we must delete all payments and re-create them from scratch.
    # As we don't have ID's, we can't be sure which payment was deleted.
    if payments.length isnt paymentForms.length
      @paymentForms.remove pf for pf in paymentForms
      @selectedPaymentFormViewModel(undefined)
      paymentForms = []

    if giftPayments.length isnt giftPaymentForms.length
      @paymentForms.remove pf for pf in giftPaymentForms
      @selectedPaymentFormViewModel(undefined)
      giftPaymentForms = []

    # Finds by index. If a payment exists in this position, update it. Else, create a new one.
    updatePayments = (payment, paymentsArray, i) =>
      try
        paymentsArray[i].update payment
      catch e
        @paymentForms.push new PaymentFormViewModel(payment, @paymentSystems, @availableAccounts, @giftCards)

    updatePayments(payment, paymentForms, i) for payment, i in payments
    updatePayments(payment, giftPaymentForms, i) for payment, i in giftPayments

    if not @selectedPaymentFormViewModel()?
      @selectedPaymentFormViewModel(@paymentForms()[0])

  update: (orderForm) =>
    paymentData = orderForm.paymentData ? {}

    if !paymentData.paymentSystems
      throw new Error('JSON enviado para PaymentData não contém paymentSystems')

    @updatePaymentSystems(paymentData)

    # If payments are inconsistent, they will be corrected and
    # a sendAttachment will be performed. Then, updating stops and awaits for
    # the new, consistent data.
    return if @adjustPayments(paymentData)

    @updateAvailableAccounts(paymentData)

    @updateGiftCards(paymentData)

    @updatePaymentForms(paymentData.payments, @getGiftsAsPayments(paymentData))

    @updateInterestTotalizer() if paymentData.payments?.length > 0

    @giftCardMessages(paymentData.giftCardMessages) if paymentData.giftCardMessages?

    #@ultraUglyAutomaticInstallmentSelectionThatShouldTotallyBeDoneByAPI()

    validationResults = @validate(dontChangeDOM: true)
    $('#payment-data').trigger('componentValidated.vtex', [validationResults])

  getGiftsAsPayments: (paymentData) =>
    giftToPayment = (g) ->
      g.groupName = 'giftCardPaymentGroup'
      g.referenceValue = parseInt(g.value, 10)
      isGift = (ps) -> ps.groupName is 'giftCardPaymentGroup'
      giftCardPaymentSystem = _.find paymentData.paymentSystems, isGift
      g.paymentSystem = giftCardPaymentSystem.id
      return g

    return _.chain(paymentData.giftCards)
    .filter('inUse')
    .map(giftToPayment)
    .value()

  # Returns true if adjustments were made to payments
  adjustPayments: (paymentData) =>
    adjustmentsMade = false
    payments = paymentData.payments
    totalToPay = @totalToPay.peek()

    if paymentData.giftCards and paymentData.giftCards.length > 0
      totalPayedByGifts = _.reduce(paymentData.giftCards, (total, gc) ->
        if gc.inUse
          return total + gc.value
        return total
      , 0)
    else
      totalPayedByGifts = 0

    if payments.length is 1 and ((payments[0].referenceValue + totalPayedByGifts) != totalToPay)
      payments[0].referenceValue = totalToPay
      adjustmentsMade = true

    # No payment exists, let's create a default
    if payments.length is 0 and totalPayedByGifts isnt totalToPay
      firstNonGiftPaymentSystem = _.find @paymentSystems(), (ps) -> ps.groupName() isnt 'giftCardPaymentGroup'
      payments.push(
        paymentSystem: parseInt(firstNonGiftPaymentSystem.id())
        referenceValue: totalToPay
      )
      adjustmentsMade = true

    for payment in payments
      # If payment has selected installment, no need to auto select
      continue if payment.installments

      paymentSystem = _.find @paymentSystems(), (ps) -> parseInt(ps.id()) is parseInt(payment.paymentSystem)
      groupName = paymentSystem.groupName()
      installments = paymentSystem.getInstallmentsForValue(payment.referenceValue)

      # Credit card with only one installment, select it automatically
      isCard = groupName in ['creditCardPaymentGroup', 'debitCardPaymentGroup', 'customCardPaymentGroup']
      if isCard
        if installments.length is 1
          payment.installments = installments[0].number()
        else
          continue # On cards with multiple installments, force user to choose
        # MercadoPago, select max installment
      else if groupName is 'MercadoPagoPaymentGroup'
        payment.installments = _.max(installments, (i) -> i.number())?.number()
        # Other payment groups, select 1 installment by default
      else
        payment.installments = 1

      adjustmentsMade = true

    if adjustmentsMade
      paymentAttachment =
        payments: payments
        giftCards: paymentData.giftCards

      window.vtexjs.checkout.sendAttachment('paymentData', paymentAttachment)

    return adjustmentsMade

# TODO: remove global declaration
window.PaymentDataViewModel = PaymentDataViewModel
window.paymentDataTemplate = template;
###
ko.components.register 'payment-data',
  viewModel: {instance: window.paymentData}
  template: template
###
