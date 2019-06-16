
## Based on jolly.exe's code from http://stackoverflow.com/questions/901115/how-can-i-get-query-string-values-in-javascript
getParameterByName = (name, search) ->
  ## https://stackoverflow.com/questions/3446170/escape-string-for-use-in-javascript-regex
  name = name.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"
  regex = new RegExp "[\\?&]#{name}=([^&#]*)"
  results = regex.exec search
  return null unless results?
  decodeURIComponent results[1].replace /\+/g, " "

## Use .checked for checkboxes and radio buttons, .value for others
getInputValue = (dom) ->
  dom.checked ? dom.value
setInputValue = (dom, value) ->
  if dom.checked?
    dom.checked = value
  else
    dom.value = value

## <input>s and <textarea>s should trigger 'input' events during every change,
## (according to HTML5), and 'change' events when the change is "committed"
## (for text fields, when losing focus).  In some browsers, checkboxes and
## radio buttons don't trigger 'input', but they immediately trigger 'change'.
## So check for both, and just ignore the event if nothing changed.
getInputEvents = (dom) ->
  ['input', 'change']

setInputValue = (dom, value) ->
  if dom.checked?
    ## Convert to Boolean checked for checkboxes and radio buttons
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
    @listeners =
      loadURL: []
      inputChange: []
      stateChange: []

    ## Coalesce multiple inputChange events into single stateChange event
    @inputsChanged = {}
    @on 'inputChange', (input) =>
      @inputsChanged[input.key] = input
      window.setTimeout =>
        @trigger 'stateChange', @inputsChanged
        @inputsChanged = {}
      , 0

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

  maybeChange: (input) ->
    input = @findInput input
    if input.value != (value = getInputValue input.dom)
      input.oldValue = input.value
      input.value = value
      @trigger 'inputChange', input
    @  # for chaining

  set: (input, value) ->
    input = @findInput input
    setInputValue input.dom, value
    @maybeChange input

  addInput: (input) ->
    if typeof input == 'string'
      input = id: input
    else if input instanceof HTMLElement
      input = dom: input
    unless input.dom?
      input.dom = document.getElementById input.id
    unless input.key?
      input.key = input.id ? input.dom.getAttribute 'id'
    unless input.defaultValue?
      input.defaultValue = input.dom.defaultChecked ? input.dom.defaultValue
    input.value = getInputValue input.dom
    @inputs.push input
    input.listeners =
      for event in getInputEvents input.dom
        input.dom.addEventListener event, listener = => @maybeChange input
        listener
    @  # for chaining

  addInputs: (selector = 'input, textarea') ->
    if typeof selector == 'string'
      selector = document.querySelectorAll selector
    for input in selector
      @addInput input
    @  # for chaining

  clearInputs: ->
    for input in @inputs
      for event, i in getInputEvents input.dom
        input.dom.removeEventListener event, input.listeners[i]
    @inputs = []
    @  # for chaining

  getState: ->
    state = {}
    for input in @inputs
      state[input.key] = getInputValue input.dom
    state

  getSearch: ->
    '?' + (
      for input in @inputs
        value = getInputValue input.dom
        ## Don't store default values
        continue if value == input.defaultValue
        ## Don't store off radio buttons; just need the "on" one
        continue if input.dom.type == 'radio' and not value
        switch value
          when true
            value = '1'
          when false
            value = '0'
        "#{input.key}=#{encodeURIComponent(value).replace /%20/g, '+'}"
    ).join '&'
  getRelativeURL: ->
    "#{document.location.pathname}#{@getSearch()}"

  loadURL: (url = document.location, trigger = true) ->
    @loading = true
    if url.search?
      search = url.search
    else if url[0] == '?'
      search = url
    else
      search = /\?.*$/.exec(url)[0]
    ## To handle radio buttons, set all to defaults, then switch to specified.
    for input in @inputs
      setInputValue input.dom, input.defaultValue
    for input in @inputs
      value = getParameterByName input.key, search
      if value?
        setInputValue input.dom, value
      input.value = getInputValue input.dom
    if trigger
      @inputsChanged = {}
      for input in @inputs
        @inputsChanged[input.key] = input
      @trigger 'stateChange', @inputsChanged
      @inputsChanged = {}
      @trigger 'loadURL', search
    @loading = false
    @  # for chaining

  setURL: (history = 'push', force) ->
    search = @getSearch()
    if force or search != document.location.search
      window.history[history+'State'] null, 'furls', "#{document.location.pathname}#{search}"
    @  # for chaining
  replaceState: (force) -> @setURL 'replace', force
  pushState: (force) -> @setURL 'push', force

  syncState: (history = 'push', loadNow = true) ->
    @on 'stateChange', =>
      @setURL history unless @loading
    window.addEventListener 'popstate', => @loadURL()
    @loadURL() if loadNow
    @  # for chaining

module?.exports = Furls
window?.Furls = Furls
