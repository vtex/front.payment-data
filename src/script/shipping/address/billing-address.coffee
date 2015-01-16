ShippingAddressViewModel = require "./shipping-address.coffee"
# Representa um endereço de cobrança
class BillingAddressViewModel extends ShippingAddressViewModel
  constructor: ->
    super()
    @moduleId = "paymentData.billingAddress"
    @isBillingAddress = true

  serializableProperties: ->
    ["addressType", "addressId", "postalCode", "street", "number", "complement", "neighborhood", "reference", "city", "state", "country"]

  getRequiredAttributes: =>
    @serializableProperties()

  validate: (options) =>
    fields = []
    fields.push(@[prop]) for prop in @serializableProperties()
    return vtex.ko.validation.validateObservables(fields, options)

# exports
module.exports = BillingAddressViewModel
