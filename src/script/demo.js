/* global $, ko, window, vtex */
'use strict';
require('./common/vtex-validation.coffee');
vtex.i18n = {
  translateHtml: function(){}
};

window.vtexjs = { checkout: {
  _getGatewayCallbackURL: '',
  sendAttachment: function(){}
} };

var OrderFormViewModel = require('./common/orderform.coffee');
window.checkout = new OrderFormViewModel();

$.getJSON('/front.payment-data/mock/orderform-1.json', function(orderForm) {
  window.vtexjs.checkout.orderForm = orderForm;
  $(window).trigger('orderFormUpdated.vtex', [orderForm]);
});

window.paymentData = new window.PaymentDataViewModel({route: 'payment'});
ko.components.register('payment-data', {
  viewModel: {instance: window.paymentData},
  template: window.paymentDataTemplate
});

ko.applyBindings();
