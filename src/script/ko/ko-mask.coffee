# Depends on jquery inputmask
ko.bindingHandlers.maskOnBlur =
	init: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
		$(element).blur ->
			maskValue = ko.utils.unwrapObservable(valueAccessor())
			if not maskValue then return true
			if valueObservable = allBindingsAccessor().value
				if (value = valueObservable())? and value.length > 0 # Check for null, undefined or empty string
					valueObservable(_.maskString(value, maskValue))
			return true
