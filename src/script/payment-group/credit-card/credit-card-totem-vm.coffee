CreditCardViewModel = require './credit-card-vm.coffee'
debug = require('debug')('creditcardtotem')

class CreditCardTotemViewModel extends CreditCardViewModel
  constructor: ->
    super
    # Inputs do numero do cartao no modo Totem
    @_cardNumberTotem = ko.observable()
    @cardNumberTotem = ko.computed
      read: =>
        @_cardNumberTotem()
      write: (value) =>
        value = value + ""
        @_cardNumberTotem value.replace(" ", "")
        @cardNumber value

    @cardNumberTotemLabel = ko.observable()
    @isScanningCard = false
    @cardRead = ""

    @canUseCardScanner = ko.computed =>
      checkout.isTotem() and paymentData.active() # TODO and paymentData.selectedPaymentGroupId() is @paymentGroup.id

    @isWaitingForCardScanner = ko.computed =>
      if @canUseCardScanner() and not @cardFormVisible()
        @isScanningCard = false
        @cardRead = ""
        $(document).on "keypress.cardScanner" + @paymentGroup.id + @id, (ev) =>
          unless @isScanningCard
            @isScanningCard = true
            setTimeout (=>
              @isScanningCard = false
              $(document).off "keypress.cardScanner" + @paymentGroup.id + @id
              @cardFormVisible true
              @parseCardRead @cardRead  if (new RegExp(/\d{10,18}/)).test(@cardRead)
              return
            ), 2000
          @cardRead += String.fromCharCode(ev.which)  if ev.which isnt 0
        true
      else
        $(document).off "keypress.cardScanner" + @paymentGroup.id + @id
        @isScanningCard = false
        false

  # constructor

  parseCardRead: (cardRead) =>
    cardLines = cardRead.split("?")
    cardOwnerName = null
    cardNumber = null
    cardNumberLabel = null
    cardDueMonth = null
    cardDueYear = null

    # Get the name from the first line
    _.each cardLines, (line, index) ->

      # Verifica se eh a trilha que contem o nome
      if index is 0 and line.indexOf("^") isnt -1
        lineOneRegex = new RegExp(/^(?:%B)([0-9]+)[^](.+)(?=\^)[^]([0-9]{4})/)
        lineResult = lineOneRegex.exec(line)
        if lineResult.length is 4
          cardNumber = lineResult[1]
          cardOwnerName = lineResult[2].trim()
          cardDueMonth = lineResult[3].substr(2, 2)
          cardDueYear = lineResult[3].substr(0, 2)

          # Replace last name
          lastNameSeparator = cardOwnerName.indexOf("/")
          if lastNameSeparator isnt -1
            lastName = cardOwnerName.substring(0, lastNameSeparator)
            firstName = cardOwnerName.substring(lastNameSeparator + 1, cardOwnerName.length)
            cardOwnerName = firstName + " " + lastName
      else

        # Verifica se eh a segunda trilha com o numero do cartao
        if line.indexOf("==") is -1 and line.indexOf("=") isnt -1
          lineTwoRegex = new RegExp(/\;([0-9]+)(?=\=)=([0-9]{4})/)
          lineResult = lineTwoRegex.exec(line)
          if lineResult.length is 3

            # The card number is in the first part of the array
            cardNumber = lineResult[1]
            cardDueMonth = lineResult[2].substr(2, 2)
            cardDueYear = lineResult[2].substr(0, 2)
            cardLastDigits = cardNumber.substr(-4, 4)
            cardNumberLabel = "●●●● ●●●● ●●●● " + cardLastDigits
      return

    if cardOwnerName
      @cardOwnerName cardOwnerName
      @isCardOwnerNameLabel true
    else
      @cardOwnerName ""
      @isCardOwnerNameLabel false
    if cardNumber
      @labelCardFields true
      @cardNumber cardNumber
      @cardNumberTotemLabel cardNumberLabel
      @cardDueMonth cardDueMonth
      @cardDueYear cardDueYear
      @cardSafetyCode ""
    else
      @labelCardFields false
      @cardFormVisible false
      @cardNumber ""
      @cardNumberTotemLabel ""
      @cardSafetyCode ""

    # Makes it focus on the next empty field
    @validate
      silent: true
      giveFocus: true

  openCardFields: =>
    @labelCardFields false

  toggleCardForm: =>
    if @cardFormVisible()
      @labelCardFields false
      @cardNumberTotem ""
      @cardNumberTotemLabel ""
      @cardSafetyCode ""
      @cardOwnerName ""
      @cardDueMonth ""
      @cardDueYear ""
    @cardFormVisible not @cardFormVisible()

module.exports = CreditCardTotemViewModel
