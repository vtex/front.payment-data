BillingAddressViewModel = require '../../shipping/address/billing-address.coffee'
ShippingAddressViewModel = require '../../shipping/address/shipping-address.coffee'
Payment = require '../../payment-system/payment.coffee'

debug = require('../../common/debug.coffee')('creditcard')
class CreditCardViewModel
  constructor: (paymentGroup) ->
    @id = (new Date().getTime() * -1).toString()
    @paymentGroup = paymentGroup
    @billingAddressRequired = ko.observable(true)
    @billingAddress = new BillingAddressViewModel()
    @cardNumber = ko.observable()
    @cardBin = ko.observable()
    @cardOwnerNameRequired = ko.observable(true)
    @cardOwnerName = ko.observable()
    @cardExpirationDateRequired = ko.observable(true)
    @cardDueMonth = ko.observable()
    @cardDueYear = ko.observable()
    @cardSafetyCodeRequired = ko.observable(true)
    @cardSafetyCode = ko.observable()
    @document = ko.observable()
    @documentPlaceholder = vtex.validation.placeholders.document[window.checkout.countryCode()]
    @documentInputType = ko.computed =>
      documentPlaceholder = vtex.validation.placeholders.document[window.checkout.countryCode()]
      if documentPlaceholder?.match(/[a-z]/i) then "text" else "tel"

    @documentAttributeBindings =
      placeholder: @documentPlaceholder

    if window.dammitIE isnt 8
      @documentAttributeBindings.type = @documentInputType

    @cardFormVisible = ko.observable(!vtex.totem)
    @labelCardFields = ko.observable(false)
    @isCardOwnerNameLabel = ko.observable(false)
    # Ao acontecer mudanças no número do cartão, tentamos sugerir a bandeira e aplicar mascara.
    @cardFlagSuggested = ko.observable(false)
    @oldFlag = ko.observable()
    @isUsingNewCard = ko.observable()
    @cardSafetyCodeHasFocus = ko.observable()
    @sameBillingAddress = ko.observable(not (vtexjs.checkout.orderForm.giftRegistryData?.addressId is vtexjs.checkout.orderForm.shippingData?.address?.addressId))
    @isCreditCardCustom = ko.observable(@paymentGroup.isCustom())
    @requiredProperties = [
      "cardNumber"
      "cardOwnerName"
      "cardDueMonth"
      "cardDueYear"
      "cardSafetyCode"
      "document"
    ]

    @cardDueDate = ko.computed =>
      @cardDueMonth() + "/" + @cardDueYear()

    @holderDocumentRequired = ko.computed =>
      @paymentGroup.paymentSystem()?.requiresDocument() ? false

    @cardCodeMask = ko.computed =>
      flag = @paymentGroup.paymentSystem()
      if flag?.cardCodeMask().length > 0
        flag.cardCodeMask()
      else
        "9999"

    @digitsValidationMessage = ko.computed =>
      i18n.t "paymentData.paymentGroup.creditCard.invalidDigits"

    @dateValidationMessage = ko.computed =>
      i18n.t "paymentData.paymentGroup.creditCard.invalidDate"

    @paymentGroup.paymentSystem.subscribe =>
      # Foi sugerida no meio da validação, aguarde.
      if @cardFlagSuggested()
        @cardFlagSuggested false
        return
      if @cardNumber.validate
        return if @isScanningCard
        @cardNumber.validate giveFocus: false

    @cardNumber.subscribe @cardNumberUpdatedHandler

    @shippingAddress = new ShippingAddressViewModel()
    if vtexjs.checkout.orderForm?.shippingData?.address
      @updateShippingAddress(vtexjs.checkout.orderForm.shippingData.address)

    $(window).on 'orderFormUpdated.vtex', (e, orderForm) =>
      return unless orderForm.shippingData?.address
      @updateShippingAddress(orderForm.shippingData.address)

  # constructor

  # TODO mover para payment group view model
  setOptionDisable: (option, item) =>
    # Estamos renderizando a caption (item === undefined) e já temos selectedInstallment, desabilite a caption.
    if typeof item is "undefined" and @paymentGroup._selectedInstallmentNumber()
      ko.applyBindingsToNode(option, {disable: true}, item)

  localizedMonth: ->
    i18n.t "paymentData.paymentGroup.creditCard.dueMonth"

  localizedYear: ->
    i18n.t "paymentData.paymentGroup.creditCard.dueYear"

  checkBIN: (cardNumber) =>
    cardNumberNoSpaces = cardNumber.replace(" ", "")
    if cardNumberNoSpaces.length >= 6
      bin = cardNumberNoSpaces.slice(0, 6)
      if not @cardBin()? or @cardBin() isnt bin
        @cardBin bin
        $("#payment-data").trigger "paymentUpdated.vtex"  if @paymentGroup.paidValue.peek() > 0

  cardNumberUpdatedHandler: (newValue) =>
    flag = undefined
    cardNumber = newValue
    ccDOMElement = $("#" + @paymentGroup.identifier() + "payment-card" + @id + "Number")[0]
    if @creditCardCustom is false

      # Reseta ao apagar todo o cartão
      if cardNumber is ""
        @paymentGroup.paymentSystem null
        @cardFlagSuggested false
        return

        # Não sugerimos e o regex é vazio - não mascare nem escolha automaticamente
      else return  if @paymentGroup.paymentSystem()? and not @cardFlagSuggested() and @paymentGroup.paymentSystem().regex().length is 0
    @checkBIN cardNumber
    if @isCreditCardCustom()
      flag = @paymentGroup.paymentSystem()
    else
      flag = @paymentGroup.findPaymentSystemByCardNumber(cardNumber)
    if flag

      # Ajuste a mascara
      # Caso tenha mudado a flag, apaga o ccv
      if not @oldFlag()? or @oldFlag() isnt flag
        @cardFlagSuggested true
        @oldFlag flag
        @cardSafetyCode ""

      # Conseguimos detectar
      @paymentGroup.paymentSystem flag
      maskedNumber = (if flag.mask().length > 0 then _.maskString(cardNumber, flag.mask()) else cardNumber)
      return  if maskedNumber is cardNumber

      # Template não está carregado.
      return  unless ccDOMElement?
      selectionStart = undefined
      selectionEnd = undefined
      if ccDOMElement.selectionStart
        selectionStart = ccDOMElement.selectionStart
        selectionEnd = ccDOMElement.selectionEnd
      @cardNumber maskedNumber
      if ccDOMElement.selectionStart
        ccDOMElement.selectionStart = @calculateNewSelectionIgnoringChars(selectionStart, cardNumber, maskedNumber, RegExp(" ", "g"))
        ccDOMElement.selectionEnd = @calculateNewSelectionIgnoringChars(selectionEnd, cardNumber, maskedNumber, RegExp(" ", "g"))
    else
      @cardFlagSuggested false

      # Sem flag
      @cardNumber cardNumber

  calculateNewSelectionIgnoringChars: (selectionIndex, stringBefore, stringAfter, ignoreRegex) =>
    beforeSubString = stringBefore.substring(0, selectionIndex)
    afterSubString = stringAfter.substring(0, selectionIndex)
    matchBefore = beforeSubString.match(ignoreRegex)
    matchAfter = afterSubString.match(ignoreRegex)
    ignoredBefore = (if matchBefore then matchBefore.length else 0)
    ignoredAfter = (if matchAfter then matchAfter.length else 0)
    selectionIndex + (ignoredAfter - ignoredBefore)

  getPayment: (masked) =>
    selectedInstallment = null
    if @paymentGroup.installments()
      selectedInstallment = @paymentGroup.selectedInstallment()?.toJSON()
    selectedPaymentSystem = @paymentGroup.paymentSystem()
    return null unless selectedPaymentSystem?
    account = @paymentGroup.selectedAvailableAccount()
    fields = {}

    # Sempre que passar informações para o Checkout
    # cairá neste caso
    # Os outros casos são para o PCI (Gateway)
    if masked
      # Envia o BIN para verificar promoção por BIN
      bin = @cardBin() if @cardBin()?
      if account? and not @isUsingNewCard.peek()
        accountId = account.accountId()
      fields = undefined
      # Caso seja um cartão salvo
    else if account? and not @isUsingNewCard.peek()
      fields =
        accountId: account.accountId()
        validationCode: @cardSafetyCode()
      # Caso seja um novo cartão
    else
      fields =
        holderName: @cardOwnerName()
        cardNumber: @cardNumber()
        validationCode: @cardSafetyCode()
        dueDate: @cardDueDate()
        document: @document()

      fields.dueDate = ""  if @cardExpirationDateRequired() is false

      # Caso seja o mesmo endereco, envie apenas o addressId
      if @sameBillingAddress()
        fields.addressId = paymentData.selectedAddressId

        # Caso seja um endereco novo, envie-o completamente
      else
        fields.address = @billingAddress.toJSON()

    new Payment
      paymentSystem: selectedPaymentSystem.id()
      paymentSystemName: selectedPaymentSystem.name()
      group: selectedPaymentSystem.groupName()
      referenceValue: @paymentGroup.paidValue()
      value: (if selectedInstallment then selectedInstallment.total else @paymentGroup.paidValue())
      installments: @paymentGroup._selectedInstallmentNumber()
      installmentsInterestRate: (if selectedInstallment then selectedInstallment.interestRate else null)
      installmentsValue: (if selectedInstallment then selectedInstallment.value else null)
      fields: fields
      bin: bin
      accountId: accountId

  validateDocument: (value, element) =>
    return result: true unless @holderDocumentRequired()
    vtex.validation.validateDocument value, element

  validateCreditCard: (value, element) =>
    validation =
      result: false
      message: ""

    paymentSystem = @paymentGroup.paymentSystem.peek()
    @cardNumber @cardNumber.peek().replace(/[A-Za-z$-]/g, "")
    cardNumber = @cardNumber.peek()

    # Não temos bandeira para validar
    return validation  unless paymentSystem?
    selectedFlagRegex = "" or paymentSystem.regex.peek()

    # Cartão não tem regex - não podemos validar.
    if selectedFlagRegex.length is 0
      validation.applyErrorClass = validation.showErrorMessage = false
      validation.applySuccessClass = not validation.applyErrorClass
      validation.result = true

      # Valide o cartão.
    else if new RegExp(selectedFlagRegex).test(cardNumber.replace(RegExp(" ", "g"), "")) and vtex.validation.validateCardDigits(paymentSystem.weights.peek(), cardNumber)
      validation.applyErrorClass = validation.showErrorMessage = false
      validation.applySuccessClass = not validation.applyErrorClass
      validation.result = true

      # Cartão customizado
    else if @isCreditCardCustom() and new RegExp(selectedFlagRegex).test(cardNumber.replace(RegExp(" ", "g"), ""))
      validation.applyErrorClass = validation.showErrorMessage = false
      validation.applySuccessClass = not validation.applyErrorClass
      validation.result = true

      # Cartão foi detectado mas está inválido.
    else
      validation.message = @digitsValidationMessage()
      validation.applyErrorClass = validation.showErrorMessage = true
      validation.applySuccessClass = not validation.applyErrorClass
      validation.result = false
    validation

  validateDate: (dmonth, dyear) =>
    today = new Date()
    year = today.getFullYear().toString().slice(2)

    # getMonth() retorna o mês atual -1.
    month = today.getMonth() + 1
    not ((dyear is year and dmonth < month) or (dmonth > 12) or (dyear < year))

  validateDueMonth: (value, element) =>
    validation =
      result: @validateDate(value, @cardDueYear())
      message: ""

    validation.applyErrorClass = validation.showErrorMessage = not validation.result
    validation.message = @dateValidationMessage()  unless validation.result
    validation

  validateDueYear: (value, element) =>
    validation =
      result: @validateDate(@cardDueMonth(), value)
      message: ""

    validation.applyErrorClass = validation.showErrorMessage = not validation.result
    validation.message = @dateValidationMessage()  unless validation.result
    validation

  validateCardCode: (cardSafetyCode, element) =>
    regex = undefined
    cardCodeRegex = undefined
    validation =
      result: false
      message: ""

    paymentSystem = @paymentGroup.paymentSystem.peek()
    unless paymentSystem?
      cardCodeRegex = /\d{3,4}/
    else
      cardCodeRegex = (if (regex = paymentSystem.cardCodeRegex.peek()) then new RegExp(regex) else /^\d{3,4}$/)
    validation.result = cardCodeRegex.test(cardSafetyCode)
    validation.message = i18n.t("paymentData.paymentGroup.creditCard.invalidDigits")  unless validation.result
    validation.applyErrorClass = validation.showErrorMessage = not validation.result
    validation

  # TODO validar installment
  validate: (options) =>
    fields = []
    if @paymentGroup.selectedAvailableAccount()?
      if @paymentGroup.selectedAvailableAccount().cardSafetyCodeRequired()
        fields.push @cardSafetyCode
    else
      fields = fields.concat _.map @requiredProperties, (f) => this[f]

      # Caso seja necessário validar o endereço
      if @billingAddressRequired() and not @sameBillingAddress()
        addressProperties = @billingAddress.serializableProperties()
        fields = fields.concat(_.map(addressProperties, (f) =>
          @billingAddress[f]
        ))
    vtex.ko.validation.validateObservables fields, options

  showNewCard: =>
    @isUsingNewCard true

  showSavedCreditCards: =>
    @isUsingNewCard false

  setupCustomCard: (paymentSystem) =>
    @paymentGroup.paymentSystem paymentSystem
    @billingAddressRequired false  unless paymentSystem.useBillingAddress()
    unless paymentSystem.useCardHolderName()
      @cardOwnerNameRequired false
      @requiredProperties = _.reject(@requiredProperties, (p) ->
        p is "cardOwnerName"
      )
    unless paymentSystem.useCvv()
      @cardSafetyCodeRequired false
      @requiredProperties = _.reject(@requiredProperties, (p) ->
        p is "cardSafetyCode"
      )
    unless paymentSystem.useExpirationDate()
      @cardExpirationDateRequired false
      @requiredProperties = _.reject(@requiredProperties, (p) ->
        p is "cardDueYear" or p is "cardDueMonth"
      )

  updateShippingAddress: (address) =>
    @shippingAddress.update(address)
    if @sameBillingAddress()
      @billingAddress.update(address)

module.exports = CreditCardViewModel
