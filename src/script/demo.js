/* global $, ko, window */
'use strict';
window.vtexjs = { checkout: {
  _getGatewayCallbackURL: ''
} };
var OrderFormViewModel = require('./common/orderform.coffee');
$.getJSON('/front.payment-data/mock/orderform-1.json', function(orderForm) {
  window.vtexjs.checkout.orderForm = orderForm;
  $(window).trigger('orderFormUpdated.vtex', [orderForm]);
});
ko.applyBindings({
  API: window.vtexjs.checkout,
  orderForm: new OrderFormViewModel()
});
