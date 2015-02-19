template = require './bank-invoice.html'
templateId = require('appendTemplate')('bank-invoice', template)

PaymentGroupViewModel = require './payment-group.coffee'
class BankInvoicePaymentGroupViewModel extends PaymentGroupViewModel
  constructor: ->
    super
    @template = templateId

module.exports = BankInvoicePaymentGroupViewModel
