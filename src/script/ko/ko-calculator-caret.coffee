ko.bindingHandlers.calculatorCaret =
	init: (element, valueAccessor, allBindings, viewModel, bindingContext) =>
		placeCaretAtEnd = ->
			el = this
			setTimeout ->
				el.focus()
				el.selectionStart = el.value.length
				el.value = el.value
			,
				10
		$(element).keydown(placeCaretAtEnd).focus(placeCaretAtEnd)
