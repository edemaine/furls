queueMicrotask = window?.queueMicrotask ? (e) -> setTimeout e, 0

## Based on jolly.exe's code from http://stackoverflow.com/questions/901115/how-can-i-get-query-string-values-in-javascript
getParameterByName = (name, search) ->
  ## https://stackoverflow.com/questions/3446170/escape-string-for-use-in-javascript-regex
  name = name.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"
  regex = new RegExp "[\\?&]#{name}=([^&#]*)"
  results = regex.exec search
  return null unless results?
  decodeURIComponent results[1].replace /\+/g, " "

## Use .checked for checkboxes and radio buttons, .value for others.
## Radio buttons use `undefined` to denote "not checked", to avoid overwriting
## the correct value from the checked button.
## Automatically parse value for type=number.
getInputValue = (dom) ->
  switch dom.type
    when 'radio'
      if dom.checked
        dom.value
    when 'checkbox'
      dom.checked
    when 'number'
      parseFloat dom.value
    else
      dom.value

getDefaultInputValue = (dom) ->
  switch dom.type
    when 'radio'
      if dom.defaultChecked
        # dom.value only works when dom.checked is true
        dom.getAttribute 'value'
    when 'checkbox'
      dom.defaultChecked
    when 'number'
      parseFloat dom.defaultValue
    else
      dom.defaultValue

setInputValue = (dom, value) ->
  switch dom.type
    when 'radio'
      dom.checked = (value == dom.getAttribute 'value')
    when 'checkbox'
      ## Convert to Boolean checked for checkboxes
      switch value
        when '1', 'true', true
          value = true
        when '0', 'false', false
          value = false
        else
          value = !!value
      dom.checked = value
    else
      dom.value = value

class Furls
  constructor: ->
    @inputs = []
    #@inputsByName = {}  # unclear this data structure is worthwhile
    @listeners =
      loadURL: []
      inputChange: []
      stateChange: []

    ## Coalesce multiple inputChange events into single stateChange event
    @inputsChanged = {}
    @on 'inputChange', (input) =>
      ## Radio buttons might trigger multiple changes, but we only want to
      ## store the one that is now checked, to avoid overwriting that one
      ## with the same name.
      return unless input.value?
      @inputsChanged[input.name] = input
      unless @microtask
        @microtask = true
        queueMicrotask =>
          @microtask = false
          return if (key for key of @inputsChanged).length == 0
          @trigger 'stateChange', @inputsChanged
          @inputsChanged = {}

  on: (event, listener) ->
    @listeners[event].push listener
    @  # for chaining
  off: (event, listener) ->
    if 0 <= i = @listeners[event].indexOf listener
      @listeners[event].splice i, 1
    @  # for chaining
  trigger: (event, ...args) ->
    for listener in @listeners[event]
      listener.call @, ...args
    @  # for chaining

  findInput: (input) ->
    ## Support various ways to specify input: internal input object,
    ## string ID of <input> element, or DOM object of <input> element.
    if input.dom?  ## Internal interface
      input
    else
      if typeof input == 'string'  ## String ID
        input = document.getElementById input
      ## DOM object
      for inputObj in @inputs
        if inputObj.dom == input
          return inputObj
      throw new Error "Could not find input given #{input}"

  maybeChange: (input, recurse = true, trigger = true) ->
    input = @findInput input
    if input.value != (value = getInputValue input.dom)
      input.oldValue = input.value
      input.value = value
      @trigger 'inputChange', input if trigger
      ## Auto-trigger change of all inputs with same name: radio buttons get
      ## events on the clicked button, but not on all the unset buttons.
      if recurse
        #for input2 in @inputsByName[input.name] when input != input2
        for input2 in @inputs
          if input2.name == input.name and input != input2
            @maybeChange input2, false
    @  # for chaining

  get: (input) ->
    @findInput(input).value
  set: (input, value) ->
    input = @findInput input
    setInputValue input.dom, value
    @maybeChange input

  ## <input>s and <textarea>s should trigger 'input' events during every change,
  ## (according to HTML5), and 'change' events when the change is "committed"
  ## (for text fields, when losing focus).  In some browsers, checkboxes and
  ## radio buttons don't trigger 'input', but they immediately trigger 'change'.
  ## So check for both, and just ignore the event if nothing changed.
  getInputEvents: (input) ->
    ['input', 'change']

  addInput: (input) ->
    if typeof input == 'string'
      input = id: input
    else if input instanceof HTMLElement
      input = dom: input
    unless input.dom?
      input.dom = document.getElementById input.id
    unless input.id?
      input.id = input.dom.getAttribute 'id'
    unless input.type?
      input.type =
        switch input.dom.tagName.toUpperCase()
          when 'TEXTAREA' then 'textarea'
          when 'INPUT' then input.dom.getAttribute 'type'
    unless input.name?
      input.name = input.dom.getAttribute('name') ? input.id
    unless input.defaultValue?
      input.defaultValue = getDefaultInputValue input.dom
    input.value = getInputValue input.dom
    @inputs.push input
    #(@inputsByName[input.name] ?= []).push input
    input.listeners =
      for event in @getInputEvents input
        input.dom.addEventListener event, listener = => @maybeChange input
        listener
    @  # for chaining

  addInputs: (selector = 'input, textarea') ->
    if typeof selector == 'string'
      selector = document.querySelectorAll selector
    for input in selector
      @addInput input
    @  # for chaining

  removeInput: (input) ->
    input = @findInput input
    for event, i in @getInputEvents input
      input.dom.removeEventListener event, input.listeners[i]
    if @_syncClass? and target.value?
      for target in @_syncClass.selector
        target.classList.remove "#{@_syncClass.prefix}#{input.name}-#{input.value}"
    @  # for chaining
  removeInputs: (selector) ->
    if typeof selector == 'string'
      selector = document.querySelectorAll selector
    else if not Array.isArray selector
      selector = [selector]
    @inputs =
      for input in @inputs
        if input in selector or input.dom in selector
          @removeInput input
          continue
        else
          input
    @  # for chaining
  clearInputs: ->
    @removeInputs @inputs

  getState: ->
    state = {}
    for input in @inputs
      value = getInputValue input.dom
      ## Avoid overwriting the correct value for radio buttons sharing a name
      if value?
        state[input.name] = value
    state

  getSearch: ->
    search = (
      for input in @inputs
        value = getInputValue input.dom
        ## Don't store default values
        continue if value == input.defaultValue
        ## Don't store off radio buttons; just need the "on" one
        continue unless value?
        ## Stringify booleans for checkboxes
        switch value
          when true
            value = '1'
          when false
            value = '0'
        "#{input.name}=#{encodeURIComponent(value).replace /%20/g, '+'}"
    ).join '&'
    search = "?#{search}" if search
    search
  getRelativeURL: ->
    "#{window.location.pathname}#{@getSearch()}"

  loadURL: (url = window.location, trigger = true) ->
    @loading = true
    if url.search?
      search = url.search
    else if url[0] == '?'
      search = url
    else
      search = /\?.*$/.exec(url)?[0] ? ''
    ## Reset all inputs to defaults before loading new values, because we
    ## only put deviation from defaults in the URL.  This needs to be in a
    ## separate stage because of checkboxes.
    for input in @inputs
      setInputValue input.dom, input.defaultValue
    for input in @inputs
      value = getParameterByName input.name, search
      if value?
        setInputValue input.dom, value
      else
        setInputValue input.dom, input.defaultValue
    ## Update values and oldValues, and optionally trigger inputChange events
    ## which trigger a stateChange event.
    for input in @inputs
      ## Don't recurse on identically named inputs, as we process all inputs.
      @maybeChange input, false, trigger
    @trigger 'loadURL', search
    ## Schedule after possibly triggered stateChange event.
    queueMicrotask => @loading = false
    @  # for chaining

  setURL: (history = 'push', force) ->
    search = @getSearch()
    if force or search != window.location.search
      window.history[history+'State'] null, 'furls', "#{window.location.pathname}#{search}"
    @  # for chaining
  replaceState: (force) -> @setURL 'replace', force
  pushState: (force) -> @setURL 'push', force

  syncState: (history = 'push', loadNow = true) ->
    @on 'stateChange', =>
      @setURL history unless @loading
    window.addEventListener 'popstate', => @loadURL()
    ## On initial load, treat as transition from undefined values to defaults.
    if loadNow
      input.value = undefined for input in @inputs
      @loadURL()
    @  # for chaining

  ## Which types have discrete values like `true` and `false`, and thus are
  ## appropriate for classes.
  discreteValue: (input) ->
    input.type in ['checkbox', 'radio']

  syncClass: (selector = [document.documentElement], prefix = '',
              updateNow = true) ->
    if typeof selector == 'string'
      selector = document.querySelectorAll selector
    else if not Array.isArray selector
      selector = [selector]
    @on 'inputChange', (input) =>
      if @discreteValue input
        for target in selector
          target.classList.remove "#{prefix}#{input.name}-#{input.oldValue}" if input.oldValue?
          target.classList.add "#{prefix}#{input.name}-#{input.value}" if input.value?
    if updateNow
      for input in @inputs when input.value?
        if @discreteValue input
          for target in selector
            target.classList.add "#{prefix}#{input.name}-#{input.value}"
    @_syncClass = {selector, prefix}
    @  # for chaining

module?.exports = Furls
window?.Furls = Furls
