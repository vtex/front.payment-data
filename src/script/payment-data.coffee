template = require("./payment-data.html")
class PaymentDataViewModel
  constructor: (params) ->
    console.log params

ko.components.register 'payment-data',
  viewModel: PaymentDataViewModel
  template: template
