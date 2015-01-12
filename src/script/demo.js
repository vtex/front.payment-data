'use strict';
var vtexjs = { checkout: {} };
/* global $ */
$.getJSON('/front.payment-data/mock/orderform-1.json', function(orderForm) {
  vtexjs.checkout.orderForm = orderForm;
});
/* global ko */
ko.applyBindings();

