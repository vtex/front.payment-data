###
Utilities to extend the Knockout JS plugin
###
#	Extend an object accounting for its observables. Always overwrites the properties in target.
#	@param target
#	@param source
#	@return {*} target, updated.
ko.utils.extendObservable = (target, source) ->
	if source
		for prop of source
			if source.hasOwnProperty(prop)

				#Case 1: target doesn't have such property. Lets create an observable for it.
				unless target.hasOwnProperty(prop)
					target[prop] = ko.observable(ko.utils.unwrapObservable(source[prop]))

					#Case 2: target already has such a property and it's an observable. Overwrite it.
				else if ko.isObservable(target[prop])
					target[prop] ko.utils.unwrapObservable(source[prop])

					#It's not an observable and not a computed
				else target[prop] = ko.utils.unwrapObservable(source[prop])  unless ko.isComputed(target[prop])
	target


#	Definição de bindingHandler para visibilidade fade-in/fade-out.
ko.bindingHandlers.fadeVisible =
	init: (element, valueAccessor) ->
		value = valueAccessor()
		$(element).toggle ko.utils.unwrapObservable(value)

	update: (element, valueAccessor) ->
		value = valueAccessor()
		(if ko.utils.unwrapObservable(value) then $(element).fadeIn() else $(element).hide())

#	Definição de bindingHandler para visibilidade fade-in/fade-out ao fazer hover em um elemento.
ko.bindingHandlers.fadeVisibleOnHover =
	init: (element, valueAccessor) ->
		# Recebe o seletor do elemento cujo hover será observado
		selector = valueAccessor()
		return unless selector
		$(element).hide()
		$(selector).on
		  mouseenter: ->
		    $(element).stop().fadeIn()
		  mouseleave: ->
		    $(element).stop().fadeOut()
		  touchstart: ->
		    $(element).fadeToggle()

#	Definição de novo bindingHandler para esse viewModel com visibilidade fade-in/fade-out para elementos inline-block
#	@type {Object}
ko.bindingHandlers.fadeInlineVisible =
	init: (element, valueAccessor) ->
		value = valueAccessor()
		$(element).toggle ko.utils.unwrapObservable(value)

	update: (element, valueAccessor, allBindingsAccessor) ->
		value = valueAccessor()
		time = if allBindingsAccessor().fadeTime then allBindingsAccessor().fadeTime else 600
		$(element).stop()
		if ko.utils.unwrapObservable(value) 
			$(element)
			.css
				opacity: 0,
				display: 'inline-block'
			.animate
				opacity: 1,
				time
		else 
			$(element)
			.css
				opacity: 1,
				display: 'inline-block'
			.animate
				opacity: 0,
				time,
				-> $(this).hide()

#	From: https://github.com/SteveSanderson/knockout/wiki/Bindings---class
#	@type {Object}
ko.bindingHandlers["class"] = update: (element, valueAccessor) ->
	ko.utils.toggleDomNodeCssClass element, element["__ko__previousClassValue__"], false  if element["__ko__previousClassValue__"]
	value = ko.utils.unwrapObservable(valueAccessor())
	ko.utils.toggleDomNodeCssClass element, value, true
	element["__ko__previousClassValue__"] = value

ko.bindingHandlers.has =
	init: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
		unless valueAccessor() of viewModel
			newValueAccesor = -> false
			ko.bindingHandlers.if.init element, newValueAccesor, allBindingsAccessor, viewModel

#	Acessa observable sem fazer subscribe a ele no contexto atual.
ko.utils.safeUnwrapObservable = (value) ->
	(if ko.isObservable(value) then value.peek() else value)
