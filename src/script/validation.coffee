window.vtex or= {}
vtex.validation or= {}

vtex.validation.validateDocument = (value, element) ->
  countryCode = window.paymentData.countryCode()
  documentKey = vtex.validation.countryToKey[countryCode]["documentKey"]
  value = '' if not value
  value = value.replace(/(_|\ )/g, '')
  validation =
    result: false
    message: (if (vtex.ko and vtex.ko.validation) then vtex.ko.validation.getValidationMessage("document") else "CPF Inválido")

  applyValidationOptions = (result) ->
    validation.applyErrorClass = validation.showErrorMessage = not result
    validation.applySuccessClass = result
    validation.result = result
    return validation

  if value is `undefined`
    return applyValidationOptions false

  #Converte para string
  value += ""

  # Validação apenas por regex para outros documentos
  unless countryCode is "BRA"
    if countryCode is "URY"
      return applyValidationOptions vtex.validation.validateCedulaURY(value)
    else if countryCode is "ECU"
      return applyValidationOptions vtex.validation.validateCedulaECU(value)
    return applyValidationOptions vtex.validation.regex[documentKey].test(value)

  cpf = value.replace(/\./g, "").replace("-", "")
  testcpf = ["11111111111", "22222222222", "33333333333", "44444444444",
             "55555555555", "66666666666", "77777777777", "88888888888", "99999999999"]
  if cpf in testcpf
    return applyValidationOptions false

  if cpf.length isnt 11
    return applyValidationOptions false

  expReg = /^0+$|^1+$|^2+$|^3+$|^4+$|^5+$|^6+$|^7+$|^8+$|^9+$/
  a = []
  b = new Number
  c = 11
  i = 0
  while i < 11
    a[i] = cpf.charAt(i)*1
    b += (a[i] * --c)	if i < 9
    i++
  if (x = b % 11) < 2
    a[9] = 0
  else
    a[9] = 11 - x
  b = 0
  c = 11
  y = 0
  while y < 10
    b += (a[y] * c--)
    y++
  if (x = b % 11) < 2
    a[10] = 0
  else
    a[10] = 11 - x

  return applyValidationOptions not ((cpf.charAt(9)*1 isnt a[9]) or (cpf.charAt(10)*1 isnt a[10]) or cpf.match(expReg))

vtex.validation.validateCNPJ = (value, element, options) ->
  options = (if options? then options else {})
  validation =
    result: false
    message: "CNPJ inválido."

  applyValidationOptions = (result) ->
    validation.applyErrorClass = validation.showErrorMessage = not result
    validation.applySuccessClass = result
    validation.result = result
    return validation

  cnpj = value
  cnpj = cnpj.replace(/[^\d]+/g, "")
  return validation	if cnpj is ""
  unless cnpj.length is 14
    return applyValidationOptions false

  # Elimina CNPJs invalidos conhecidos
  testcnpj = ["00000000000000", "11111111111111", "22222222222222", "33333333333333", "44444444444444",
              "55555555555555", "66666666666666", "77777777777777", "88888888888888", "99999999999999"]
  if cnpj in testcnpj
    return applyValidationOptions false

  # Valida DVs
  tamanho = cnpj.length - 2
  numeros = cnpj.substring(0, tamanho)
  digitos = cnpj.substring(tamanho)
  soma = 0
  pos = tamanho - 7
  i = tamanho
  while i >= 1
    soma += numeros.charAt(tamanho - i) * pos--
    pos = 9	if pos < 2
    i--
  resultado = (if soma % 11 < 2 then 0 else 11 - soma % 11)
  return applyValidationOptions false	unless resultado is digitos.charAt(0)*1
  tamanho = tamanho + 1
  numeros = cnpj.substring(0, tamanho)
  soma = 0
  pos = tamanho - 7
  i = tamanho
  while i >= 1
    soma += numeros.charAt(tamanho - i) * pos--
    pos = 9	if pos < 2
    i--
  resultado = (if soma % 11 < 2 then 0 else 11 - soma % 11)
  return applyValidationOptions (resultado is digitos.charAt(1)*1)

vtex.validation.validateCardDigits = (weights, cardNumberRaw) ->
  return true if weights.length is 0
  sum = 0
  j = undefined
  i = undefined
  cardNumber = cardNumberRaw.replace(RegExp(" ", "g"), "")

  #Ve se tem o numero de digitos certo do cartão.
  i = 0
  while i < cardNumber.length - 1
    weight = weights[i]
    digit = cardNumber.substring(i, i + 1) * 1
    tempResult = (digit * weight).toString()
    if tempResult.length is 1
      tempResult = tempResult * 1 # casting to int
      sum += tempResult
    else
      j = 0
      while j < tempResult.length
        aux = tempResult.substring(j, j + 1) * 1
        sum += aux
        j++
    i++

  #Verificando a soma e o resto para validar ultimo digito.
  #resto = soma % 10
  verifierDigit = sum % 10
  verifierDigit = 10 - verifierDigit	unless verifierDigit is 0
  if (cardNumber.substring(cardNumber.length - 1, cardNumber.length) * 1) is verifierDigit
    true
  else
    false

vtex.validation.validateCedulaURY = (value) ->
  value = value.replace(/\-|\./g, "")
  intArray = []

  for c in value
    intArray.push(parseInt(c))

  #array base para validação no Uruguai
  baseArray = [8, 1, 2, 3, 4, 7, 6]

  verifiyDigit = 0

  #executa o cálculo para criação do dígito verificador
  for value, i in baseArray
    verifiyDigit += baseArray[i] * intArray[i]

  verifiyDigit %= 10

  #valida o dígito verificador
  return verifiyDigit == intArray[intArray.length - 1]


vtex.validation.validateRUCPER = (ruc) ->
  validation =
    result: false
    message: vtex.ko.validation.getValidationMessage(window.paymentData.locale(), 'corporateDocument')

  applyValidationOptions = (result) ->
    validation.applyErrorClass = validation.showErrorMessage = not result
    validation.applySuccessClass = result
    validation.result = result
    return validation

  rucRegex = new RegExp(/^[0-9]{11}$|^[0-9]{8}$/)
  if rucRegex.test(ruc)
    # converte o array de caracteres em um array de inteiros
    intArray = _.map ruc, (character) -> parseInt(character)

    if ruc.length is 8
      sum = 0

      prop = [1..intArray.length - 1]
      for a, i in prop
        char = intArray[i]
        if i is 0
          sum += char * 2
        else
          sum += (char * (intArray.length - i))

      mod = sum % 11
      if mod is 1
        mod = 11

      if mod + intArray[intArray.length - 1] is 11
        return applyValidationOptions(true)
    else # nesse caso tem 11 dígitos o RUC
      sum = 0
      x = 6

      prop = [1..intArray.length - 1]
      for a, i in prop
        char = intArray[i]
        if i is 4
          x = 8

        x--

        sum += char * x

      mod = sum % 11
      mod = 11 - mod

      if mod >= 10
        mod -= 10

      if mod is intArray[intArray.length - 1]
        return applyValidationOptions(true)

  return applyValidationOptions(false)

vtex.validation.validateCedulaECU = (value) ->

  # o número é formado por 10 dígitos, podendo ter um '-' entre o nono e o décimo
  if RegExp(/^[0-9]{9}-[0-9]{1}$|^[0-9]{10}$/).test(value)
    # remove traços contidos no documento
    documentWithOnlyNumbers = value.replace("-", "")

    # converte o array de caracteres em um array de inteiros
    intArray = []
    for c in documentWithOnlyNumbers
      intArray.push(parseInt(c))

    # os dois primeiros dígitos correspondem à província e devem ser um número de 01 a 24
    provinceCode = intArray[0] * 10 + intArray[1]
    if provinceCode < 1 || provinceCode > 24
      return false;

    evenDigitsSum = 0
    oddDigitsSum = 0

    # percorre o array de dígitos desconsiderando o dígito verificador
    i = 0
    while i < intArray.length - 1
      # soma-se todos os dígitos de posição par do array
      # verifica se a posição atual é par (+1 é devido ao fato do array começar na posição zero)
      if ((i + 1) % 2 == 0)
        evenDigitsSum += intArray[i]
        # os dígitos da posição ímpar devem ser multiplicador por 2. Se o resultado da multiplicação der um número maior que 9, subtrair 9 a esse número.
        # Ao final, somar o resultado de todas essas contas
      else
        oddDigitMultiplied = intArray[i] * 2
        if oddDigitMultiplied > 9
          oddDigitMultiplied -= 9
        oddDigitsSum += oddDigitMultiplied

      i++

    # o dígito verificador é calculado pela subtração da próxima dezena da soma dos cálculos acima pelo resultado da soma

    # cálcula a soma dos resultados acima
    sum = oddDigitsSum + evenDigitsSum

    # calcula a próxima dezena
    temp = sum / 10.0
    temp = Math.ceil(temp);
    nextDozen = temp * 10

    # calcula o dígito verificador
    calculatedVerifyDigit = nextDozen - sum

    # verifica se o calculado é igual ao passado
    return calculatedVerifyDigit == intArray[intArray.length - 1]

  else
    return false

vtex.validation.masks =
  cep: "99999-999"
  zip: "99999"
  cpARG: "9999"
  cpCHL: "9999999"
  cpECU: "9999"
  cpCOL: "99999"
  cpURY: "99999"
  cpPRY: "9999"
  cpPER: "9999"
  cpMEX: "99999"

  cuit: "99-99999999-9"
  dayMonth: "99/99"
  cnpj: "99.999.999/9999-99"
  phoneBRA: { mask: "(99) 9999-9999[9]", placeholder: "_" }
  phoneARGPart1: { mask: "99[99]", placeholder: "" }
  phoneARGPart3: { mask: "999999[9999]", placeholder: "" }
  phoneUSA: "(999) 999-9999"
  phoneCHLPart1: "9[9]"
  phoneCHLPart2: "999999[9][9]"
  phoneURY: { mask: "99999999[9]", placeholder: "", showMaskOnHover: false }
  phonePRYNDC: mask: "99[9]"

  cpf: { mask: "999.999.999-99", autoUnmask: true}
  dni: { mask: "99999999", autoUnmask: true}
  rutCHL: { mask: "99.999.999-*", autoUnmask: true}
  cedulaECU: { mask: "999999999-9", autoUnmask: true}
  cedulaCOL: { mask: "******[******]", autoUnmask: true}
  cedulaURY: { mask: "9.999.999-9", autoUnmask: true}
  cedulaPRY: { mask: "99999999", autoUnmask: true}
  documentPER: { mask: "************", placeholder: "", showMaskOnHover: false }

  ssn: "999-99-9999"
  rucECU: "9999999999999"
  rucPRY: "99999999999"
  rucPER: "99999999999"
  numeric: "999999999999"

vtex.validation.placeholders =
  document:
    ARG: '99999999'
    BRA: '999.999.999-99'
    CHL: '99.999.999-K'
    USA: '999-99-9999'
    PRY: '99999999'
    ECU: '999999999-9'
    URY: '9.999.999-9'
  companyDocument:
    BRA: '99.999.999/9999-99'
  phone:
    ECU: '9 999-9999'
    COL: '9 999 9999'
    BRA: '11 99999-9999'
    USA: '999 999-9999'

vtex.validation.countryToKey =
  ARG:
    postalCode: 'cpARG'
    document: 'dni'
    documentKey: 'dni'
    corporateDocument: 'cuit'
    phone: 'phoneARGPart3'
  BRA:
    postalCode: 'cep'
    document: 'cpf'
    documentKey: 'cpf'
    corporateDocument: 'cnpj'
    phone: 'phoneBRA'
  CHL:
    postalCode: 'cpCHL'
    document: 'rutCHL'
    documentKey: 'rutCHL'
    corporateDocument: 'rutCHL'
    phone: 'phoneCHL'
  USA:
    postalCode: 'zip'
    document: 'ssn'
    documentKey: 'ssn'
  # nao possui, vide: http://en.wikipedia.org/wiki/Value_added_tax
    corporateDocument: 'cnpj'
    phone: 'phoneUSA'
  ECU:
    postalCode: 'cpECU'
    document: 'cedulaECU'
    documentKey: 'cedulaECU'
    corporateDocument: 'rucECU'
    phone: 'phoneECU'
  COL:
    postalCode: 'cpCOL'
    document: 'cedulaCOL'
    documentKey: 'cedulaCOL'
    corporateDocument: 'cedulaCOL'
    phone: 'phoneCOL'
  URY:
    postalCode: 'cpURY'
    document: 'cedulaURY'
    documentKey: 'cedulaURY'
    corporateDocument: 'cedulaURY'
    phone: 'phoneURY'
  PRY:
    postalCode: 'cpPRY'
    document: 'cedulaPRY'
    documentKey: 'cedulaPRY'
    corporateDocument: 'cedulaPRY'
    phone: 'phonePRY'
  PER:
    postalCode: 'cpPER'
    document: 'dni'
    documentKey: 'documentPER'
    corporateDocument: 'rucPER'
    phone: 'phonePER'
  MEX:
    postalCode: 'cpMEX'
    document: 'rfc'
    documentKey: 'documentMEX'
    corporateDocument: 'rfc'
    phone: 'phoneMEX'

#	A map of regex for validating user inputs.
#	@type {regex}
vtex.validation.regex =
  # Default - CEP
  postalCode: /^([\d]{5})\-?([\d]{3})$/
# Default - CPF
  document: /^([\d]{3})\.?([\d]{3})\.?([\d]{3})\-?([\d]{2})$/

# ARG
  cpARG: /^([\d]{4})$/
  dni: /^[A-z]?\d{6,8}$/
  cuit: /^([\d]{2})\-?([\d]{8})\-?([\d]{1})$/

# BRA
  cep: /^([\d]{5})\-?([\d]{3})$/
  cpf: /^([\d]{3})\.?([\d]{3})\.?([\d]{3})\-?([\d]{2})$/
# cpnj usa uma funcao de validacao especifica

# CHL
  cpCHL: /^([\d]{7})$/
  rutCHL: /^0*(\d{1,3}(\.?\d{3})*)\-?([\dkK])$/

# USA
  zip: /^([\d]{5})$/
  ssn: /^\d{3}\-?\d{2}\-?\d{4}$/

# ECU
  cpECU: /^([\d]{4})$/
  cedulaECU: /^(\d{9})\-(\d{1})$/
  rucECU: /^\d{13}$/

# COL
  cpCOL: /^([\d]{5})$/
  cedulaCOL: /^(\w{6,12})$/

# URY
  cpURY: /^([\d]{5})$/
  cedulaURY: /^\d{1}\.\d{3}\.\d{3}\-\d{1}$/

# PER
  cpPER: /^([\d]{4})$/
  documentPER: /^[a-zA-Z0-9]{8,12}$/
  rucPER: /^[0-9]{11}$|^[0-9]{8}$/

# PRY
  cpPRY: /^([\d]{4})$/
  cedulaPRY: /^(\w{4,8})$/

# MEX
  cpMEX: /^\d{5}$/
  documentMEX: /^[a-zA-Z]{4}[0-9]{6}[a-zA-Z0-9]{3}$/
  rfc: /^[a-zA-Z]{3}[0-9]{6}[a-zA-Z0-9]{3}$/

  other: /^\S$/
  email: /[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?/
  dueDate: /\d\d\/\d\d/
  creditCardCode: /\d{3,4}/
  alpha: /^[A-Za-zÀ-ž\s]*$/
  numeric: /^[0-9\s]*$/
  alphaNumeric: /^[A-Za-zÀ-ž-0-9\s]*$/
  alphaNumericPunctuation: /^[A-Za-zÀ-ž0-9\/\\\-\.\,\s\(\)\'\#ªº]*$/
  numericPunctuation: /^[0-9-\--\.-\/]*$/
  exemptValidation: /.*/

#	A map of validation messages to be shown when validation fails.
#	@type {string}
vtex.validation.messages =
  "en-US":
    postalCode: "Enter a valid postal code, please."
    document: "Enter a valid document, please."
    corporateDocument: "Enter a valid corporate document number, please."
    tel: "Enter a valid phone number, please."
    email: "Enter a valid email, please."
    required: "This field is required."
    generic: "Invalid."
    dueDate: "Invalid date."
    creditCardCode: "Invalid code."
    alpha: "Enter only letters, please."
    numeric: "Enter only numbers, please."
    alphaNumeric: "Enter only letters or numbers, please."
    alphaNumericPunctuation: "Invalid characters."
    numericPunctuation: "Enter only numbers, hyphens, dots and slashes, please."
  "es":
    postalCode: "Introduzca un código postal válido, por favor."
    document: "Introduzca un documento válido, por favor."
    corporateDocument: "Introduzca un número válido de documento de la empresa, por favor."
    tel: "Introduzca un número de teléfono válido, por favor."
    email: "Introduzca un correo electrónico válido, por favor."
    required: "Este campo es obligatorio."
    generic: "No válido."
    dueDate: "Fecha no válida."
    creditCardCode: "Código no válido."
    alpha: "Introduzca sólo letras, por favor."
    numeric: "Introduzca sólo números, por favor."
    alphaNumeric: "Introduzca sólo letras o números, por favor."
    alphaNumericPunctuation: "Caracteres no válidos."
    numericPunctuation: "Introduzca sólo números, guiones, puntos y barras, por favor."
  "pt-BR":
    postalCode: "Informe um CEP válido."
    document: "Informe um documento válido."
    corporateDocument: "Informe um documento válido."
    tel: "Informe um número de telefone válido."
    email: "Informe um email válido."
    required: "Campo obrigatório."
    generic: "Campo inválido."
    dueDate: "Data inválida."
    creditCardCode: "Código inválido."
    alpha: "Digite apenas letras."
    numeric: "Digite apenas números."
    alphaNumeric: "Digite apenas letras e/ou números."
    alphaNumericPunctuation: "Caracteres inválidos."
    numericPunctuation: "Digite apenas números, hífens, pontos e barras"

###
This plugin declares two new bindings for use in KnockoutJS templates: "validate" and "required".
See README.md and docs.html for details on usage.

@title Validation plugin for KnockoutJS 2.2
@author Guilherme Rodrigues (guilherme.rodrigues@vtex.com.br)
@github https://github.com/vtex/ko-validation
@version 0.8.2
###
#  Namespace creation, if necessary
window.vtex or= {}
vtex.ko or= {}
vtex.ko.validation or= {}
# This helper allows us to get an observable value without binding to it's context
ko.utils.safeUnwrapObservable = ko.utils.safeUnwrapObservable or (value) -> (if ko.isObservable(value) then value.peek() else value)

#  Default options for the validation plugin
vtex.ko.validation.defaults =
  event: "blur"
  successEvent: "keyup"
  targetBind: "value"
  validationErrorClass: "error"
  validationSuccessClass: "success"
  requiredErrorClass: "required"
  showErrorMessage: undefined
  applyErrorClass: undefined
  applySuccessClass: undefined
  validateOnEvent: true
  fadeError: false
  fadeSpanTime: 350
  fadeSpeed: 75
  locale: "en-US"

vtex.ko.validation.options = {}
$.extend vtex.ko.validation.options, vtex.ko.validation.defaults

#  A map of regex for validating user inputs.
#  @type {regex}
vtex.ko.validation.regex = vtex.validation.regex

#  A map of validation messages to be shown when validation fails.
#  @type {string}
vtex.ko.validation.messages = vtex.validation.messages

#  Validate handler.
#  Upon initialization, the handler registers a new function "validate" on the target observable.
ko.bindingHandlers.validate = init: (element, valueAccessor, allBindingsAccessor) ->
  allBindings = allBindingsAccessor()
  validationEvent = allBindings.validationEvent or vtex.ko.validation.options.event
  successEvent = allBindings.successEvent or vtex.ko.validation.options.successEvent
  requiredEvent = allBindings.requiredEvent or vtex.ko.validation.options.event
  validationRule = allBindings["validate"]
  validationTargetBind = allBindings.validationTargetBind or vtex.ko.validation.options.targetBind
  customValidationFunction = (if typeof (validationRule) is "function" then validationRule else undefined)
  validationTarget = allBindings[validationTargetBind]
  validationTarget.lastValidationResult = ko.observable()

  # If there is no such property, throw an error and abort validation.
  throw new Error("validationTargetBind is not correctly set. Set it to the binding with the attribute you are trying to validate, e.g. 'value' or 'text'")  unless validationTarget?

  #  The "validate" function assigned to the observable property. You can call "property.validate()"
  #  at any time to perform validation.
  #
  #  @param options.showErrorMessage whether to show or hide the error message
  #  @param options.applyErrorClass whether to apply or remove the error class
  #  @param options.applySuccessClass whether to apply or remove the success class
  #  @param options.className the name of the class to insert in element and in the span message
  #  @param options.giveFocus if showing the error, also give the element focus
  #  @return {validation} an object in the form {result: boolean, message: "string"}, or the result of
  #  a custom validation function.
  validationFunction = (options) ->
    # Retrieve the value which should be validated.
    value = (if ko.isObservable(allBindings[validationTargetBind]) then allBindings[validationTargetBind].peek() else allBindings[validationTargetBind])
    # Clean mask character IF they are the only ones present
    value = '' if value? and value.replace and $.trim(value.replace(/_|\.|-/g,'')) is ''
    valueIsEmpty = not value? or value.length is 0
    validation = {}
    requiredFailed = false
    validationOptions = $.extend({}, vtex.ko.validation.options, options)
    requiredBinding = (if ko.isObservable(allBindings["required"]) then allBindings["required"].peek() else allBindings["required"])
    validationTargetIsRequired = allBindings["required"]? and requiredBinding isnt false

    # Check required validation. - skips other validations if failed.
    if validationTargetIsRequired
      if valueIsEmpty
        requiredFailed = true
        validation =
          result: false
          message: vtex.ko.validation.getValidationMessage("required")
          empty: true
        # Until now, our guess is this is valid.
      else
        validation =
          result: true
          message: ""
          empty: false
      # If field is not required, then when it is empty, dont applySuccessClass
    else
      if valueIsEmpty
        options = {} unless options?
        options.applySuccessClass = false

    # Regex rule name provided, validate against it.
    if not requiredFailed and validationRule? and not customValidationFunction
      validationOptions = $.extend({}, vtex.ko.validation.options, options)

      #Only show the error if there's actually a value being validated.
      validation = vtex.ko.validation.validateField(validationRule, value)

    # Custom validation function provided. Skip it if required check failed.
    if not requiredFailed and customValidationFunction?
      # Call the custom validation function, passing the element for custom manipulation
      validation = customValidationFunction(value, element, options)
      validationOptions = $.extend(validationOptions, validation)

    # Supress errors (case when VTEX KO Validation wants to update input validation result)
    if validationOptions.supressError is true
      validationOptions.applyErrorClass = validationOptions.showErrorMessage = false

    # If it was not validated at all, we set arbitrary values
    if validation.result is undefined
      validation =
        result: true
        message: ""
        empty: true
      validationOptions.showErrorMessage = validationOptions.applySuccessClass = validationOptions.applyErrorClass = false
    else
      validationOptions.showErrorMessage = not validation.result if validationOptions.showErrorMessage is undefined
      validationOptions.applyErrorClass = not validation.result if validationOptions.applyErrorClass is undefined
      validationOptions.applySuccessClass = validation.result if validationOptions.applySuccessClass is undefined

    # Show or hide the validation error in the interface
    vtex.ko.validation.toggleValidationError(element, validation.message, validationOptions) unless validationOptions.dontChangeDOM

    # Always save the validation result in the element data vtex-valid
    $(element).data('vtex-valid', validation.result)
    validationTarget.lastValidationResult(validation.result)
    validation

  # Insert the validation function in the observable.
  validationTarget.validate = validationFunction
  if vtex.ko.validation.options.validateOnEvent
    eventsToListen = _.uniq([validationEvent, requiredEvent])
    $(element).on eventsToListen.join(" "), ->
      validationFunction()
      true

    $(element).on successEvent, ->
      # Validate at each key press. The validation results will be stored at data vtex-valid
      validationFunction(dontChangeDOM: true)
      if $(this).data('vtex-valid') isnt undefined
        # If there's a error message, dont supress it
        if $(this).data('vtex-validation-message') is true
          validationFunction(applySuccessClass: $(this).data('vtex-valid'))
          # Otherwise, the validation should not show an error message
        else
          validationFunction(supressError: true, applySuccessClass: $(this).data('vtex-valid'))
      true

#  Required handler for the validation plugin.
#  This handler serves simply as a "marker" to the validation function.
#  The validation handler actually checks the value.
ko.bindingHandlers.required =
  init: (element, valueAccessor, allBindingsAccessor) ->
    allBindings = allBindingsAccessor()
    # in this case we use unwrapObservable instead of safeUnwrapObservable because we do want to subscribe to the computed
    valueUnwraped = ko.utils.unwrapObservable(valueAccessor())

    return if valueUnwraped is false

    #Initialize with the validate binding, if it doesn't exists
    ko.bindingHandlers.validate.init element, valueAccessor, allBindingsAccessor  unless allBindings["validate"]?

#  Shows an error on the DOM
#  @param element the element on which it should operate.
#  @param message the message to be inserted as a "<span>" next to this element
#  @param options.showErrorMessage whether to show or hide the error message
#  @param options.applyErrorClass whether to apply or remove the error message
#  @param options.errorClassName the name of the class to insert in element and in the span message when invalid
#  @param options.sucessClassName the name of the class to insert in element and in the span message when valid
#  @param options.giveFocus if showing the error, also give the element focus
vtex.ko.validation.toggleValidationError = (element, message, options) ->
  errorClassName = options.className or vtex.ko.validation.options.validationErrorClass
  successClassName = options.successClassName or vtex.ko.validation.options.validationSuccessClass
  showErrorMessage = options.showErrorMessage
  applyErrorClass = options.applyErrorClass
  applySuccessClass = options.applySuccessClass
  fadeError = options.fadeError
  fadeSpanTime = options.fadeSpanTime
  fadeSpeed = options.fadeSpeed
  if options.silent
    applySuccessClass = applyErrorClass = showErrorMessage = false
  giveFocus = options.giveFocus

  # Bootstrap error support
  bootstrapControlGroup = $(element).closest("div.control-group")
  helpClass = "help"
  spanError = $(element).siblings("." + errorClassName + "." + helpClass)
  if showErrorMessage is true
    if spanError.length is 0
      span = document.createElement("span")
      $(span).text message
      $(span).addClass helpClass
      $(span).addClass errorClassName
      $(span).hide() if fadeError
      $(element).parent().append span
      if fadeError
        setTimeout ->
          $(span).fadeIn fadeSpeed
        , fadeSpanTime
    else
      spanError.text message
      $(element).data('vtex-validation-message', true)
  else if showErrorMessage is false
    spanError.remove()
    $(element).data('vtex-validation-message', false)

  # Aux functions
  changeValidationClass = (add, className, bootstrapClass) ->
    addOrRemove = (if add then 'addClass' else 'removeClass')
    bootstrapControlGroup[addOrRemove](bootstrapClass) unless bootstrapControlGroup.length is 0
    $(element)[addOrRemove](className)

  addValidationClass = (className, bootstrapClass) ->
    changeValidationClass(true, className, bootstrapClass)

  removeValidationClass = (className, bootstrapClass) ->
    changeValidationClass(false, className, bootstrapClass)

  # Bootstrap error support
  if applyErrorClass is true
    addValidationClass(errorClassName, "error")
    removeValidationClass(successClassName, "success")
  else if applyErrorClass is false
    removeValidationClass(errorClassName, "error")

  # Bootstrap success support
  if applySuccessClass is true
    addValidationClass(successClassName, "success")
    removeValidationClass(errorClassName, "error")
  else if applySuccessClass is false
    removeValidationClass(successClassName, "success")

  if giveFocus and $(element).is(':visible')
    if $('.modal').is(':visible')
      giveFocusOnModalHidden = -> $(element).focus() unless $('.modal').is(':visible')
      $('.modal').one 'hidden', ->
        # Quando o modal sumir, espere 300 ms
        setTimeout((->
          # Outro modal apareceu, vamos cadastrar o callback novamente.
          if $('.modal').is(':visible')
            $('.modal').one 'hidden', giveFocusOnModalHidden
            # Nenhum outro modal apareceu, podemos chamar o callback.
          else
            giveFocusOnModalHidden()
        ), 300)
    else
      $(element).focus()

#  Validate a value against a regex rule.
#  @param validationRule regex rule
#  @param value value being validated
#  @return {validation} a validation object structured like: {result: boolean, message: string}
vtex.ko.validation.validateField = (validationRule, value) ->
  validation =
    result: true
    message: ""

  valueTest = value or ""
  validation.result = (if vtex.ko.validation.regex[validationRule].test(valueTest) then true else false)  if vtex.ko.validation.regex[validationRule]

  #Caso tenha falhado a validação, preencha a mensagem.
  validation.message = vtex.ko.validation.getValidationMessage(validationRule)  unless validation.result
  validation

#  Example custom validation function which can be bound to "validate".
#
#  @param value the value being validated
#  @param element the DOM Element to which validation has been bound.
#  @return whatever you return here will also be returned by the "validate()" function in your observable.
#  The usual return value is an object structured like {result: boolean, message: 'string'}
vtex.ko.validation.customValidation = (value, element) ->
  result = false

  #Your validation code here
  result = true  unless value?

  #This is the structure of the "validation" object returned by the default validation function.
  validation =
    result: result
    message: "Custom validation failed!"

  # These properties will be used by the plugin to manipulate the DOM.
  validation.showErrorMessage = not validation.result
  validation.applyErrorClass = not validation.result
  validation.applySuccessClass = validation.result

  # This will also be the return value of the "validate()" function.
  validation

#  Encapsules the validation message retrieving.
#  Redefine this for usage with a custom internationalization plugin.
#  @param key Key to find
#  @param locale Locale to use for the internationalization
#  @return Localized string
vtex.ko.validation.getValidationMessage = (key, locale) ->
  defaultLocale = (if vtex.ko.validation.messages[vtex.ko.validation.options.locale] then vtex.ko.validation.options.locale else vtex.ko.validation.defaults.locale)
  localeMessages = vtex.ko.validation.messages[locale] or vtex.ko.validation.messages[defaultLocale]
  localeMessages[key] or localeMessages["generic"]

# Helper function to validating multiple observables, for example, in a form.
# Gives focus to the first invalid field, if found.
# Returns an array of validation results.
vtex.ko.validation.validateObservables = (observables, options = {giveFocus: true, silent: true}) ->
  focusOnFirstFalse = options.giveFocus
  options.giveFocus = false
  validationResults = []
  validateProperty = (prop) ->
    return unless prop.validate
    validation = prop.validate(options)
    validationResults.push validation
    if focusOnFirstFalse and validation.result is false
      focusOptions = giveFocus: true, applyErrorClass: options.applyErrorClass, dontChangeDOM: options.dontChangeDOM,
      applySuccessClass: options.applySuccessClass, showErrorMessage: options.showErrorMessage, silent: options.silent
      prop.validate(focusOptions)
      focusOnFirstFalse = false

  validateProperty o for o in observables
  return validationResults
