class Payment
  constructor: (json) ->
    @paymentSystem = json.paymentSystem
    @paymentSystemName = json.paymentSystemName
    @group = json.group
    @installments = json.installments
    @installmentsInterestRate = json.installmentsInterestRate ? 0
    @installmentsValue = json.installmentsValue ? json.value
    @value = json.value
    @referenceValue = json.referenceValue
    @fields = json.fields
    @availableAccounts = json.availableAccounts
    @bin = json.bin
    @accountId = json.accountId

    deviceFingerprint = window.vtex.deviceFingerprint?.toString?()
    if deviceFingerprint
      @fields or= {} # If not defined on json
      @fields['deviceFingerprint'] = deviceFingerprint

module.exports = Payment
