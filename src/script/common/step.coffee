module.exports =
  active: ko.observable false
  visited: ko.observable false
  loading: ko.observable false

  enable: ->
    @visited true
    @active true

    if @hasOwnProperty @isValid
      validationOptions =
        giveFocus: true
        showErrorMessage: false
        applyErrorClass: false

      @isValid validationOptions

  disable: ->
    @active false
