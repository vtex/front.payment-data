template = require './debit.html'
templateId = require('appendTemplate')('debit', template)

PaymentGroupViewModel = require './payment-group.coffee'
class DebitPaymentGroupViewModel extends PaymentGroupViewModel
  constructor: ->
    super
    @template = templateId

module.exports = DebitPaymentGroupViewModel
