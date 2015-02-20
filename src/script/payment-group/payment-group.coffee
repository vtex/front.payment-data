template = require './generic.html'
templateId = require('appendTemplate')('payment-group', template)
payPalTemplate = require './paypal.html'
payPalTemplateId = require('appendTemplate')('paypal', payPalTemplate)
safetyPayTemplate = require './safetypay.html'
safetyPayTemplateId = require('appendTemplate')('safetypay', safetyPayTemplate)

Payment = require '../payment-system/payment.coffee'

debug = require('debug')('paym-group')
class PaymentGroupViewModel
  constructor: (paymentSystemsArray, availableAccountsObservableArray) ->
    @id = (new Date().getTime() * -1).toString() + Math.random().toString(36).substr(2)
    # As every payment system belongs to the same payment group, we can use the first one for these generic infos
    ps = paymentSystemsArray[0]

    @name = ps.name()
    @isCustom = ko.observable(ps.isCustom())
    @nameSlug = if ps.isCustom() then (_.sanitize(_.spacesToHyphens(ps.name()))).toLowerCase() else ''
    @className = if @nameSlug then 'pg-' + @nameSlug else ''
    @description = ps.description()
    @groupName = ko.observable(ps.groupName())
    @paidValue = ko.observable()
    updatePaidValueDebounce = _.debounce ((paidValue) =>
      @paidValue(paidValue)
    ), 1000

    @_paidValueInput = ko.observable(0)
    @paidValueInput = ko.computed
      read: =>
        _.formatCurrency(@_paidValueInput() / 100)
      write: (newValue) =>
        newValue += "" # to String
        intValue = parseInt(newValue.replace(/[\.,]/g, ""), 10) or 0 # to Int
        @_paidValueInput(intValue)
        return if @paidValue.peek() is intValue
        updatePaidValueDebounce(intValue)

    previousPaidValue = 0
    @paidValue.subscribe (value) =>
      if value > 0 and value isnt previousPaidValue
        @_paidValueInput(value)
        $(window).trigger('paidValueUpdated.vtex', [{paidValue: value, paymentGroupId: @id}]) # Request installments
        installments = @paymentSystem().getInstallmentsForValue(value)
        if not installments?
          $(window).trigger('paymentUpdated.vtex') # Request installments
        else
          @installments(installments) # Update installments
          selectedInstallmentNumber = @_selectedInstallmentNumber()
          correspondingSelectedInstallment = _.find installments, (i) => i.number() is @_selectedInstallmentNumber()
          if selectedInstallmentNumber? and not correspondingSelectedInstallment?
            @_selectedInstallmentNumber(undefined) # Unselect installment if it doesn't exist in new installments

      previousPaidValue = value

    @paymentSystems = ko.observableArray(paymentSystemsArray)
    @availableAccountsObservableArray = availableAccountsObservableArray
    @availableAccounts = ko.computed =>
      paymentSystemIdArray = _.map(paymentSystemsArray, (ps) -> parseInt(ps.id()))
      # Whenever the global availableAccounts change, this will be updated
      _.filter availableAccountsObservableArray(), (aa) ->
        paymentSystemId = parseInt(aa.paymentSystem.id.peek())
        paymentSystemId in paymentSystemIdArray

    @selectedAvailableAccount = ko.observable()

    @unusedAvailableAccounts = ko.computed =>
      _.reject @availableAccounts(), (aa) =>
        aa.selected() and aa isnt @selectedAvailableAccount()

    @template = ko.observable switch @name
      when 'PayPal' then payPalTemplateId
      when 'Safetypay' then safetyPayTemplateId
      else templateId

    @localizedLabel = ko.computed =>
      groupName = @groupName()
      translationKey = "paymentData.paymentGroup." + groupName.replace("PaymentGroup", "") + ".name"
      translation = i18n.t translationKey
      # Se não existe tradução para esse meio, retorne o fallback da API
      if translation is translationKey then return @name else return translation

    @localizedDescription = ko.computed =>
      groupName = @groupName()
      translationKey = "paymentData.paymentGroup." + groupName.replace("PaymentGroup", "") + ".description"
      translation = i18n.t translationKey
      # Se não existe tradução para esse meio, retorne o fallback da API
      if translation is translationKey then return @description ? @name else return translation

    @paymentSystem = ko.observable(paymentSystemsArray[0])
    previousPaymentSystem = null
    # Always send payments if payment system changed
    @paymentSystem.subscribe (paymentSystem) =>
      paidValue = @paidValue.peek()
      if paymentSystem? and paymentSystem isnt previousPaymentSystem and paidValue > 0
        $(window).trigger('paymentUpdated.vtex')
      previousPaymentSystem = paymentSystem

    @installments = ko.observableArray()

    @selectedInstallment = ko.computed =>
      _.find @installments(), (i) => i.number() is @_selectedInstallmentNumber()

    @_selectedInstallmentNumber = ko.observable()
    # Encapsula _selectedInstallmentNumber para bind na tela.
    # Quando muda, sabemos que foi o usuário que selecionou.
    @selectedInstallmentNumber = ko.computed
      read: =>
        @_selectedInstallmentNumber()
      write: (installmentNumber) =>
        return unless installmentNumber

        currentInstallmentNumber = @_selectedInstallmentNumber.peek()
        @_selectedInstallmentNumber(installmentNumber)

        newInstallmentIsDifferent = currentInstallmentNumber? and (currentInstallmentNumber isnt installmentNumber)
        if (not currentInstallmentNumber?) or newInstallmentIsDifferent
          debug 'changed installment from', currentInstallmentNumber, 'to', installmentNumber
          $(window).trigger('paymentUpdated.vtex')

    @maxInstallmentOptionFunction = (installments) ->
      if installments then return _.max(installments, (i) -> i.number()) else undefined

    @maxInstallmentOption = ko.computed =>
      @maxInstallmentOptionFunction(@installments())

    @installmentsCaption = ko.computed =>
      i18n.t("paymentData.paymentGroup.installmentsCaption")

  setAvailableAccount: (availableAccountViewModel) =>
    @selectedAvailableAccount()?.selected(false)
    if availableAccountViewModel
      availableAccountViewModel.selected(true)
      @paymentSystem availableAccountViewModel.paymentSystem
    @selectedAvailableAccount(availableAccountViewModel)

  selectAvailableAccount: (availableAccountViewModel) =>
    # If it's already selected, don't select it again. May be in another payment.
    return if availableAccountViewModel?.selected()
    @setAvailableAccount(availableAccountViewModel)
    $(window).trigger('paymentUpdated.vtex') if @paidValue() > 0 and availableAccountViewModel

  removeAvailableAccount: (availableAccountViewModel) =>
    window.vtexjs.checkout.removeAccountId(availableAccountViewModel.accountId())
    # removes from the global availableAccounts array
    @availableAccountsObservableArray.remove availableAccountViewModel

  updatePayment: (payment) =>
    # Caso seja um pagamento salvo, selecione por accountId
    if payment.accountId
      availableAccount = _.find @availableAccounts(), (aa) -> aa.accountId() is payment.accountId
      @setAvailableAccount(availableAccount)
    # Selecione o paymentSystem, se houver
    else if payment.paymentSystem
      ps = _.find(@paymentSystems(), (ps) -> parseInt(ps.id()) is parseInt(payment.paymentSystem))
      if ps isnt @paymentSystem()
        @paymentSystem(ps)
    # Caso contrário, selecione o primeiro disponível
    else
      @paymentSystem(@paymentSystems()[0])

    @paidValue(payment.referenceValue)
    @updateInstallments(payment.installments)

  updateInstallments: (installmentNumber) =>
    oldInstallmentNumber = @_selectedInstallmentNumber() ? installmentNumber
    installments = @paymentSystem().getInstallmentsForValue(@paidValue())
    if installments?
      if oldInstallmentNumber
        @_selectedInstallmentNumber(oldInstallmentNumber)
      @installments(installments)
    else
      debug("No installments for current paid value #{@paidValue()} on paymentSystem #{@paymentSystem().id()}")
      @_selectedInstallmentNumber(null)
      @installments(null)
      if @paidValue() > 0
        paymentData.sendAttachment() # Request installments

  # Retorna o pagamento preenchido desse grupo. Implementação default, com 1 installment.
  # @param masked se o pagamento deve ser gerado sem informações críticas (como número de cartão)
  # @return {*}
  getPayment: (masked) =>
    total = @paidValue()
    return undefined if total is 0

    selectedInstallment = @selectedInstallment()?.toJSON()
    payment = new Payment
      paymentSystem: @paymentSystem().id()
      paymentSystemName: @paymentSystem().name()
      group: @paymentSystem().groupName()
      value: if selectedInstallment then selectedInstallment?.total else total
      referenceValue: total
      installments: @_selectedInstallmentNumber()
      installmentsInterestRate: selectedInstallment?.interestRate
      installmentsValue: selectedInstallment?.value
    return payment

  validate: ->
    [result: true] if @paidValue() > 0

  isValid: ->
    validationResults = @validate(options or giveFocus: true)
    validationResults.length > 0 and _.all validationResults, (val) -> val.result is true

module.exports = PaymentGroupViewModel

