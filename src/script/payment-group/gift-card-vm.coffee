class GiftCardViewModel
  constructor: (json = {}) ->
    @id = json.id ? (new Date().getTime() * -1).toString() + Math.random().toString(36).substr(2)
    @redemptionCode = ko.observable(null)
    @value = ko.observable(null)
    @balance = ko.observable(null)
    @name = ko.observable(null)
    @inUse = ko.observable(null)
    @isSpecialCard = ko.observable(null)
    @caption = ko.observable(null)
    @captionClass = ko.observable(null)
    @provider = ko.observable(null)

    @update json

    @valueLabel = ko.computed => _.intAsCurrency @value()
    @balanceLabel = ko.computed => _.intAsCurrency @balance()
    @friendlyName = ko.computed =>
      return @caption() if @caption()
      i18n.t('global.'+ @name())

  update: (json) =>
    @redemptionCode json.redemptionCode
    @value json.value
    @balance json.balance
    @name json.name
    @inUse(json.inUse ? false)
    @isSpecialCard(json.isSpecialCard ? false)
    @caption json.caption
    @captionClass _.spacesToHyphens(json.caption+'').toLowerCase() if json.caption
    @provider json.provider

  toJSON: =>
    id: @id
    redemptionCode: @redemptionCode()
    value: @value()
    referenceValue: @value()
    balance: @balance()
    name: @name()
    inUse: @inUse()
    isSpecialCard: @isSpecialCard()
    provider: @provider()

module.exports = GiftCardViewModel
