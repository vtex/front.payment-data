Module = require 'Module'
Translatable = require 'Translatable'
Step = require 'Step'
Routable = require 'Routable'
PaymentFormViewModel = require './payment-form/payment-form.coffee'
PaymentSystem = require './payment-system/payment-system.coffee'
AvailableAccountViewModel = require './payment-group/credit-card/available-account-vm.coffee'
GiftCardListViewModel = require './gift-card/gift-card-list.coffee'
require './validation.coffee'
require './ko/ko-calculator-caret.coffee'
require './ko/ko-utils.coffee'
require './ko/ko-mask.coffee'

debug = require('debug')('payment')

class PaymentDataViewModel extends Module
  @include Translatable
  @include Routable
  @include new Step()

  constructor: (params) ->
    @id = 'paymentData'
    @route = params.route
    @location = params.location

    @setupRouter()

    @paymentSystems = ko.observableArray([])
    @availableAccounts = ko.observableArray([])
    # Created if there is a gift card payment system available on first update
    @giftCardList = ko.observable()
    @giftCards = ko.observableArray([])
    @paymentForms = ko.observableArray([])
    @selectedPaymentFormViewModel = ko.observable()
    @giftCardMessages = ko.observableArray([])
    @validationError = ko.observable(false)
    @locale = ko.observable()
    @totalToPay = ko.observable()
    @loggedIn = ko.observable()
    @useCardScanner = ko.observable()
    @countryCode = ko.observable('BRA')
    @gatewayCallbackURL = ko.observable('/checkout/gatewayCallback/{0}/{1}/{2}')
    @loading = ko.observable(false)
    @giftRegistryAddressId = ko.observable()
    @shippingAddress = ko.observable()
    @items = ko.observableArray([])
    @isTotem = ko.observable(window.location.href.indexOf('totem') isnt -1)

    @totalPaid = ko.computed =>
      payments = @getPayments(true)
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

  addPaymentForm: =>
    # Don't add a payment unless all existing payments are valid
    return unless _.all @validatePaymentForms(giveFocus: true, showErrorMessage: true, applyErrorClass: false), (r) -> r.result

    diff = @totalPaidDifference()
    newPayment =
      referenceValue: if diff > 0 then diff else 0
      installment: 1

    paymentForm = new PaymentFormViewModel(newPayment, @paymentSystems, @availableAccounts)
    @paymentForms.push paymentForm
    @selectPaymentForm paymentForm

  removePaymentForm: (paymentForm) =>
    debug 'remove payment', paymentForm
    if paymentForm is @selectedPaymentFormViewModel()
      indexOfPaymentForm = _.indexOf(@paymentForms(), paymentForm)
      newPaymentFormIndex = Math.abs(indexOfPaymentForm - 1) # if 0, select 1
      @selectedPaymentFormViewModel(@paymentForms()[newPaymentFormIndex])
    @paymentForms.remove(paymentForm)
    paymentForm.selectedPaymentGroupViewModel()?.selectedAvailableAccount()?.selected(false)
    @sendAttachment()
    return false

  selectPaymentForm: (paymentFormViewModel) =>
    # Don't select a payment unless current is valid
    return unless _.all @selectedPaymentFormViewModel()?.validate(giveFocus: true, showErrorMessage: true, applyErrorClass: false), (r) -> r.result

    debug 'select payment', paymentFormViewModel
    @selectedPaymentFormViewModel(paymentFormViewModel)

  clearValidationError: => @validationError false

  getPaymentFormPayments: (masked) =>
    _.chain(@paymentForms()).map((pf) -> pf.getPayment(masked)).compact().value()

  getPayments: (masked) =>
    payments = @getPaymentFormPayments(masked)
    if @giftCardList()
      payments = payments.concat @giftCardList().getPayments()

    return payments

  # Sends payments to checkout API to decide if there are installments or benefits available
  sendAttachment: =>
    paymentAttachment =
      payments: @getPaymentFormPayments(true)
      giftCards: _.map @giftCards(), (g) -> g.toJSON()

    $(window).trigger('sendAttachment.vtex', ['paymentData', paymentAttachment])

  paidValueUpdatedHandler: (e, data) =>
    totalToPay = @totalToPay()
    paymentForms = @paymentForms()
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
    return if @items.peek().length is 0

    @sendAttachment()

  # @return {string} O array de Payments serializados como JSON
  paymentsArrayJSON: => return JSON.stringify @getPayments()

  validatePaymentForms: (options) =>
    _.chain(@paymentForms()).map((pf) -> pf.validate(options)).flatten().value()

  validatePaidValue: =>
    totalPaidByPaymentForms = _.reduce(@getPayments(true), ((memo, p)-> memo + p.referenceValue), 0)
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
    if not @active()
      return false

    validationResults = @validate()
    $('#payment-data').trigger('componentValidated.vtex', [validationResults])

    if not _.all(validationResults, (v) -> v.result)
      return false

    # TODO move this to validation of paymentForm?
    paymentSystemRequiresAuthentication = _.any @paymentForms(), (pf) -> pf.requiresAuthentication()
    authenticated = @loggedIn() or @userType is 'callCenterOperator'
    if paymentSystemRequiresAuthentication and not authenticated
      return @authenticateBeforePaying(@submit)

    payments = @getPayments(true)
    value = _.reduce(payments, ((memo, p)-> memo + p.value), 0)
    referenceValue = _.reduce(payments, ((memo, p)-> memo + p.referenceValue), 0)
    @loading true
    $('#payment-data').trigger('startTransaction.vtex', [value, referenceValue, payments])
    return false

  sendPayments: (transactionResponse) =>
    transactionURL = transactionResponse.receiverUri
    merchantTransactions = transactionResponse.merchantTransactions
    transactionPayments = transactionResponse.paymentData.payments
    currencyCode = transactionResponse.storePreferencesData.currencyCode
    payments = @getPayments()

    # Caso seja pagamento utilizando a nova API do Checkout que suporta split
    if merchantTransactions? and merchantTransactions.length > 0
      payments = @splitPayments(payments, merchantTransactions, transactionPayments, currencyCode)

    paymentsJSON = JSON.stringify payments
    $("#sendPayments").attr('action', transactionURL)
    $("#paymentsArray").val paymentsJSON
    if transactionResponse.gatewayCallbackTemplatePath
      gatewayUrl = @location.protocol + '//' + @location.host + transactionResponse.gatewayCallbackTemplatePath
      $("#callbackURL").val gatewayUrl
    $("#sendPayments").submit()

  splitPayments: (payments, merchantTransactions, transactionPayments, currencyCode) =>
    paymentsArray = []

    # No caso de gift card, devemos pegar o primeiro merchant (API ainda nao sabe
    # como vai lidar com isso)
    giftPayments = _.filter payments, (p) -> p.group is "giftCardPaymentGroup"
    for giftPayment in giftPayments
      giftPayment.transaction =
        id: merchantTransactions[0].transactionId
        merchantName: merchantTransactions[0].merchantName
    paymentsArray = paymentsArray.concat(giftPayments)

    # No caso de pagamentos "normais" (não gift card)
    for payment, i in payments
      for transactionPayment, j in transactionPayments
        if i is j
          # Para cada merchantSellerPayments do payment
          # criamos um pagamento novo
          for merchant in transactionPayment.merchantSellerPayments
            newPayment = _.clone payment
            # A API do Checkout manda dentro do merchantSellerPayments
            # o valor que será pago por cada pagamento, para isso, sobescrevemos
            # o nosso objeto payment com os valores enviados pela API
            _.extend newPayment, merchant

            # Pegaremos agora no objeto merchantTransactions o número da
            # transação e atrelamos ao pagamento
            merchantId = newPayment.id
            transaction = _.find merchantTransactions, (m) -> m.id is merchantId
            newPayment.transaction =
              id: transaction.transactionId
              merchantName: transaction.merchantName

            # hardcode installmentsValue
            newPayment.installmentsValue = newPayment.installmentValue

            # Repassa o currency code da transação
            newPayment.currencyCode = currencyCode

            # Adicionamos ao array de pagamentos
            paymentsArray.push(newPayment)

    payments = paymentsArray

  authenticateBeforePaying: (callback) =>
    options =
      userEmail: @email
      title: i18n.t('paymentData.requiresAuthentication')

    $(window).trigger("authenticateUser.vtexid", [options])

    $(window).one 'authenticatedUser.vtexid', ->
      callback()

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
    giftCardPaymentSystems = _.filter @paymentSystems(), (ps) -> ps.groupName() is 'giftCardPaymentGroup'
    # There is a gift card payment system and the list has not been initialized
    if giftCardPaymentSystems?.length > 0 and not @giftCardList()
      @giftCardList new GiftCardListViewModel(giftCardPaymentSystems[0], @giftCards)

    if paymentData.giftCards.length != @giftCards().length
      @giftCards.removeAll()

    for giftCardJSON, i in paymentData.giftCards
      giftCard = _(@giftCards()).find (gc) =>
        return gc.id() is giftCardJSON.id or
          gc.redemptionCode() is giftCardJSON.redemptionCode

      if giftCard
        giftCard.update giftCardJSON
      else
        @giftCardList().addGiftCard(giftCardJSON)

  updatePaymentForms: (payments) =>
    paymentForms = @paymentForms()

    # If we have less payments now then before, we must delete all payments and re-create them from scratch.
    # As we don't have ID's, we can't be sure which payment was deleted.
    if payments.length isnt paymentForms.length
      @paymentForms.removeAll()
      @selectedPaymentFormViewModel(undefined)
      paymentForms = []

    # Finds by index. If a payment exists in this position, update it. Else, create a new one.
    updatePayments = (payment, paymentsArray, i) =>
      try
        paymentsArray[i].update payment
      catch e
        @paymentForms.push new PaymentFormViewModel(payment, @paymentSystems, @availableAccounts)

    updatePayments(payment, paymentForms, i) for payment, i in payments

    if not @selectedPaymentFormViewModel()?
      @selectedPaymentFormViewModel(@paymentForms()[0])

  update: (orderForm) =>
    if orderForm.clientPreferencesData?.locale?
      @locale if orderForm.clientPreferencesData.locale.match 'es-' then 'es' else orderForm.clientPreferencesData.locale
    @email = orderForm.clientProfileData?.email
    @userType = orderForm.userType
    @loggedIn orderForm.loggedIn
    @totalToPay _.reduce(orderForm.totalizers, ((memo, t) -> memo + t.value), 0)
    @countryCode orderForm.storePreferencesData?.countryCode
    @giftRegistryAddressId orderForm.giftRegistryData?.addressId
    @shippingAddress orderForm.shippingData?.address
    @items orderForm.items

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

    @updatePaymentForms(paymentData.payments)

    @giftCardMessages(paymentData.giftCardMessages) if paymentData.giftCardMessages?

    validationResults = @validate(dontChangeDOM: true)
    $('#payment-data').trigger('componentValidated.vtex', [validationResults])

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
        referenceValue: totalToPay - totalPayedByGifts
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

      $(window).trigger('sendAttachment.vtex', ['paymentData', paymentAttachment])

    return adjustmentsMade

# TODO: remove global declaration
###
ko.components.register 'payment-data',
  viewModel: {instance: window.paymentData}
  template: template
###

# TODO: use address component
bra = require('./shipping/locales/bra')
usa = require('./shipping/locales/usa')
vtex.localeUtils =
  BRA: bra
  BRA: usa

module.exports = PaymentDataViewModel
