localeUtils = vtex.localeUtils
templateBRA = require './bra.html'
templates = {}
templates['BRA'] = require('appendTemplate')('shipping-address-bra', templateBRA)

Module = require 'Module'

# Representa um endereço
class ShippingAddressViewModel extends Module
  constructor: ->
    instanceId = (new Date().getTime() * -1).toString()
    @moduleId = "shippingData.shippingAddress"
    @postalCodeChangedSubscription = {}
    @addressUpdatedFromServer = false

    @addressType = ko.observable("residential") # residential | commercial
    @postalCode = ko.observable(null)
    @postalCodeFound = ko.observable(false)
    @street = ko.observable(null)
    @number = ko.observable(null)
    @complement = ko.observable(null)
    @neighborhood = ko.observable(null)
    @reference = ko.observable(null)
    @city = ko.observable(null)
    @state = ko.observable('')
    @receiverName = ko.observable(null)
    @addressId = ko.observable(instanceId)
    @disableCity = ko.observable(false)
    @disableState = ko.observable(false)
    @labelShippingFields = ko.observable(false)
    @logisticsInfo = ko.observableArray()
    @slasForSellerViewModelArray = ko.observableArray()
    @loading = ko.observable(false)
    @throttledLoading = ko.computed(=>@loading()).extend(throttle:500)

    @maskedStreet = ko.computed => _.maskInfo(@street())
    @maskedNumber = ko.computed => _.maskInfo(@number())
    @maskedComplement = ko.computed => _.maskInfo(@complement())
    @maskedNeighborhood = ko.computed => _.maskInfo(@neighborhood())
    @maskedCity = ko.computed => _.maskInfo(@city())
    @maskedState = ko.computed => _.maskInfo(@state())
    @maskedReference = ko.computed => _.maskInfo(@reference())
    @maskedPostalCode = ko.computed => _.maskInfo(@postalCode())

    @addressTypeCommercial = ko.computed
      read: => @addressType() is "commercial"
      write: (value) => @addressType (if value is true then "commercial" else "residential")

    @deliveryCountry = ko.observable "BRA" #TODO suporte a demais países
    @nameForCountry = (country) -> i18n.t "global." + country
    @deliveryCountryName = ko.computed =>  @nameForCountry @deliveryCountry()

    @addressTemplate = ko.computed =>
      templates[@deliveryCountry()]

    @deliveryCountry.subscribe (deliveryCountry) =>
      @postalCode ""
      @postalCodeFound false

    countriesWithNoPostalCode = ['ECU', 'CHL', 'COL', 'PRY']
    countriesWithPostalCodeAccordingToCity = ['CHL', 'COL', 'PRY']

    @isNotUsingPostalCode = ko.computed =>
      @deliveryCountry() in countriesWithNoPostalCode

    @isPostalCodeAccordingToCity = ko.computed =>
      @deliveryCountry() in countriesWithPostalCodeAccordingToCity

    @country = ko.computed => @deliveryCountry()
    @postalCodeRegex = ko.computed =>
      countryToKey = vtex.validation.countryToKey[@deliveryCountry()]
      if not countryToKey?
        countryToKey = vtex.validation.countryToKey[@defaultDeliveryCountry()]
        @deliveryCountry @defaultDeliveryCountry()
      vtex.validation.regex[countryToKey.postalCode]
    @postalCodeMask = ko.computed =>
      countryToKey = vtex.validation.countryToKey[@deliveryCountry()]
      if not countryToKey?
        countryToKey = vtex.validation.countryToKey[@defaultDeliveryCountry()]
        @deliveryCountry @defaultDeliveryCountry()
      vtex.validation.masks[countryToKey.postalCode]

    @isSelected = ko.computed
      read: =>
        shippingData.currentAddressId() is @addressId()
      deferEvaluation: true

    @firstPart = ko.computed =>
      value = ""
      value += _.maskInfo(@street())
      value += ", " + _.maskInfo(@number())  if @number() and @deliveryCountry() isnt "USA"
      value += ", " + _.maskInfo(@complement())  if @complement()
      value += ", " + _.maskInfo(@reference())  if @reference()
      value

    @secondPart = ko.computed =>
      value = ""
      value += _.maskInfo(@city()) + " - "  if @city()
      value += _.maskInfo(@state()) + " - "  if @state()
      value += i18n.t("global."+@country())
      value

    @summary = ko.computed =>
      value = ""
      value += _.maskInfo(@street())
      value += " - " + _.maskInfo(@postalCode())  if @postalCode()
      value

    @showSlasForSeller = ko.computed =>
      array = @slasForSellerViewModelArray()
      postalCodeFound = @postalCodeFound()
      return array?.length > 0 and postalCodeFound

    @loadingSlasForSeller = ko.computed =>
      array = @slasForSellerViewModelArray()
      @postalCodeFound() and array is undefined

    @clearAddressIfPostalCodeNotFound = ko.computed =>
      return not @isNotUsingPostalCode()

    @showPostalCode = ko.computed =>
      if @deliveryCountry() is "BRA"
        @postalCodeFound() is true and @postalCodeRegex().test(@postalCode())
      else
        true

    @changePostalCodeBasedOnState = ko.computed =>
      if @isPostalCodeAccordingToCity() or
         not @isNotUsingPostalCode() or
         not @state()
        return

      currentPostalCode = null
      for city of localeUtils[@deliveryCountry()].map[@state()]
        currentPostalCode = localeUtils[@deliveryCountry()].map[@state()][city]
        break

      return if not currentPostalCode

      @addressUpdatedFromServer = false
      @postalCode(currentPostalCode)
    .extend(throttle: 1000)

    @changePostalCodeBasedOnCity =  _.throttle(=>
      if not @isPostalCodeAccordingToCity() or
         not @isNotUsingPostalCode() or
         not @state()
        return

      currentPostalCode = null
      if @deliveryCountry() is "CHL" and @neighborhood()
        currentPostalCode = localeUtils[@deliveryCountry()].map[@state()][@neighborhood()]
      else if @city()
        currentPostalCode = localeUtils[@deliveryCountry()].map[@state()][@city()]
      return if not currentPostalCode

      # Publica esse endereço
      @addressUpdatedFromServer = false
      @postalCode(currentPostalCode)
    , 1000)

    @citiesBasedOnState = ko.computed =>
      deliveryCountry = @deliveryCountry()
      return if deliveryCountry in ["BRA", "USA"] or not @state()

      if localeUtils[deliveryCountry].map
        if not localeUtils[deliveryCountry].cities[@state()]
          localeUtils[deliveryCountry].cities[@state()] = _.map(localeUtils[deliveryCountry].map[@state()], (k, v) -> return v )
        return localeUtils[deliveryCountry].cities[@state()]

      if @isNotUsingPostalCode() and not @isPostalCodeAccordingToCity()
        @changePostalCodeBasedOnState()

      return localeUtils[deliveryCountry].cities[juridicCode]

    @isGift = ko.computed =>
      @addressType() is 'giftRegistry'

    $(window).on 'deliverySelected.vtex', @handleDeliverySelected

  # end constructor

  select: => shippingData.currentAddressId @addressId()

  # Insere zeros a esquerda
  pad: (num, size) =>
    s = num+""
    while (s.length < size)
      s = "0" + s
    return s

  serializableProperties: ->
    ["addressType", "addressId", "postalCode", "street", "number", "complement", "neighborhood", "reference", "city", "state", "receiverName", "country", "clearAddressIfPostalCodeNotFound"]

  forceShippingFields: =>
    @labelShippingFields false

  toJSON: =>
    json = {}
    for key in @serializableProperties()
      attr = ko.toJS(@[key])
      json[key] = attr

    json.street = _.capitalizeSentence(json.street)
    json.neighborhood = _.capitalizeSentence(json.neighborhood)
    json.city = _.capitalizeSentence(json.city)

    return json

  # Atualiza esse endereço com as informações do parametro address, um JSON de endereço.
  update: (address, logisticsInfo) =>
    @loading false
    postalCodeChanged = false
    @deliveryCountry address.country  if address.country
    @street _.capitalizeSentence(address.street)  if postalCodeChanged or (address.street and address.street.length > 0)
    @neighborhood _.capitalizeSentence(address.neighborhood)  if postalCodeChanged or (address.neighborhood and address.neighborhood.length > 0)

    # Backwards compability para mudanca de nome de provincia
    if address.state in ["Ciudad de Buenos Aires", "Provincia de Buenos Aires"]
      address.state = "Ciudad Autónoma de Buenos Aires"
      address.city = "Ciudad Autónoma Buenos Aires"

    @city _.capitalizeSentence(address.city)  if postalCodeChanged or (address.city and address.city.length > 0)
    @number address.number  if postalCodeChanged or (address.number and address.number.length > 0)
    @complement address.complement  if postalCodeChanged or (address.complement and address.complement.length > 0)
    @addressType address.addressType if address.addressType
    @addressId address.addressId  if address.addressId
    if (address.receiverName)
      @receiverName address.receiverName
    @reference address.reference  if address.reference
    if address.postalCode
      #Ignore the next address update
      @addressUpdatedFromServer = true
      # Trata caso do hiphen do CEP estar transformado em asterisco
      if address.postalCode.length is 9 and address.postalCode[0] is '*' and address.country is 'BRA'
        postalCodeSanitized = address.postalCode[1..]
      else
        postalCodeSanitized = address.postalCode
      @postalCode _.maskString(postalCodeSanitized, @postalCodeMask())
      @postalCodeFound true

    # postaLCode atualizado, addressUpdatedFromServer deve ser falso
    @disableCity (address.city isnt undefined and address.city isnt "")
    @disableState (address.state isnt undefined and address.state isnt "")

    # Suprime inputs caso API retorne com campos do endereço
    if address.street and address.neighborhood and address.city and address.state and !@isNotUsingPostalCode()
      @labelShippingFields true
    else
      @labelShippingFields false

    if logisticsInfo
      @handleDeliverySelected(null, logisticsInfo)
    else
      @validate(giveFocus: true, silent: true)

    return this

  validate: (options) =>
    fields = []
    fields.push(@[prop]) for prop in @serializableProperties()
    return vtex.ko.validation.validateObservables(fields, options)

  isValid: (options) =>
    return true if @addressType() is 'giftRegistry'
    validationResults = @validate(options or giveFocus: true)
    validationResults.length > 0 and _(validationResults).all (val) -> val.result is true

  isComplete: =>
    return true if @addressType() is 'giftRegistry'
    for attr in @getRequiredAttributes()
      unwrapped = ko.utils.safeUnwrapObservable(this[attr])
      return false if unwrapped is undefined or unwrapped is null or unwrapped.toString().replace(/_|-/g, '').length is 0
    return true

  getRequiredAttributes: =>
    if @deliveryCountry() in ["COL","USA"]
      return ["addressType", "addressId", "receiverName", "postalCode", "street", "city", "state", "country"]
    else if @deliveryCountry() in ["ARG","ECU","URY"]
      return ["addressType", "addressId", "receiverName", "postalCode", "street", "city", "state", "country", "number"]
    else if @deliveryCountry() is "CHL"
      return ["addressType", "addressId", "receiverName", "postalCode", "street", "state", "country", "number"]
    else
      return ["addressType", "addressId", "receiverName", "postalCode", "street", "neighborhood", "city", "state", "country", "number"]

module.exports = ShippingAddressViewModel
