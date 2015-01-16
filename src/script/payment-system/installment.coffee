# Parcela de pagamento. Ex: 3x de R$ 298, tem number 3 e value 298.
# @param {number} number numero dessa parcela.
# @param {value} value dessa parcela.
# @param {hasInterestRate} tem juros.
# @param {interestRate} porcentagem de juros.
# @param {total} valor final do pagamento com a determinada quantia de parcelamentos
class Installment
  constructor: (json) ->
    @number = ko.observable()
    @value = @price = ko.observable()
    @hasInterestRate = ko.observable()
    @interestRate = ko.observable()
    @total = ko.observable()

    @update(json)

    @text = ko.computed =>
      if @number() is 1
        i18n.t("paymentData.paymentGroup.creditCard.payInCash") + " - " + _.intAsCurrency(@value())
      else if @hasInterestRate()
        @number() + i18n.t("paymentData.paymentGroup.creditCard.installmentsInterestPrefix") + " " + _.intAsCurrency(@value()) + " " + i18n.t("paymentData.paymentGroup.creditCard.installmentsInterestSuffix") + _.formatCurrency(@interestRate()/100) + i18n.t("paymentData.paymentGroup.creditCard.installmentsInterestPeriod")
      else
        @number() + i18n.t("paymentData.paymentGroup.creditCard.installmentsInterestPrefix") + " " + _.intAsCurrency(@value()) + " " + i18n.t("paymentData.paymentGroup.creditCard.installments")

  update: (json) =>
    @number(json.count)
    @value(json.value)
    @hasInterestRate(json.hasInterestRate)
    @interestRate(json.interestRate)
    @total(json.total)

  toJSON: =>
    number: @number()
    value: @value()
    hasInterestRate: @hasInterestRate()
    interestRate: @interestRate()
    total: @total()

# exports
module.exports = Installment
