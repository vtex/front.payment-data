class OrderFormViewModel
  locale: ko.observable('pt-BR')
  loggedIn: ko.observable(false)
  canEditData: ko.observable(true)
  salesChannel: ko.observable(1)
  countryCode: ko.observable('BRA')
  total: ko.observable()

  constructor: ->
    $(window).on('orderFormUpdated.vtex', @parseOrderForm)
    if (orderForm = window.vtexjs.checkout.orderForm)?
      @parseOrderForm(orderForm)

  parseOrderForm: (orderForm) =>
    if orderForm.clientPreferencesData and orderForm.clientPreferencesData.locale
      if orderForm.clientPreferencesData.locale.match 'es-'
        locale = 'es'
      else
        locale = orderForm.clientPreferencesData.locale
      @locale(locale)

    if orderForm.storePreferencesData and orderForm.storePreferencesData.countryCode
      @countryCode(orderForm.storePreferencesData.countryCode)

    @canEditData(orderForm.canEditData)
    @loggedIn(orderForm.loggedIn)
    @total(orderForm.total)

    if orderForm.salesChannel
      @salesChannel(orderForm.salesChannel)

module.exports = OrderFormViewModel
