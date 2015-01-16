template = require './debit.html'
templateId = require('../common/append-template.coffee')('debit', template)

PaymentGroupViewModel = require './payment-group.coffee'
class DebitPaymentGroupViewModel extends PaymentGroupViewModel
  constructor: ->
    super
    @template = templateId

module.exports = DebitPaymentGroupViewModel
