module.exports =
  handleChanges: (newHash, oldHash) ->
    newHash += ''
    oldHash += ''

    routeRegex = new RegExp(@route)

    newHit = routeRegex.test(newHash)
    oldHit = routeRegex.test(oldHash)

    if newHit
      @enter?(newHash, oldHash)
    else if not newHit and oldHit
      @exit?(newHash, oldHash)

  redirect: (to) ->
    hasher.replaceHash(to)

  go: (to) ->
    hasher.setHash(to)

  included: ->
    # Add hash change listener
    hasher.changed.add(@::handleChanges)
    # Add initialized listener (to grab initial value in case it is already set)
    hasher.initialized.add(@::handleChanges)
