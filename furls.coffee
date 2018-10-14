### TODO:
 - coalesce multiple inputChange's into single stateChange?
###

## Based on jolly.exe's code from http://stackoverflow.com/questions/901115/how-can-i-get-query-string-values-in-javascript
getParameterByName = (name, search) ->
  ## https://stackoverflow.com/questions/3446170/escape-string-for-use-in-javascript-regex
  name = name.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"
  regex = new RegExp "[\\?&]#{name}=([^&#]*)"
  results = regex.exec search
  return null unless results?
  decodeURIComponent results[1].replace /\+/g, " "

getInputValue = (dom) ->
  ## Use .checked for checkboxes and radio buttons, .value for others
  dom.checked ? dom.value

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
      stateChange: []

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

  maybeChange: (input) ->
    if input.value != (value = getInputValue input.dom)
      input.value = value
      @trigger 'inputChange', input
    @  # for chaining

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

  loadURL: (url = document.location) ->
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
    @  # for chaining

  replaceState: (force) ->
    search = @getSearch()
    if force or search != document.location.search
      history.replaceState null, 'furls', "#{document.location.pathname}#{search}"
    @  # for chaining
  pushState: (force) ->
    search = @getSearch()
    if force or search != document.location.search
      history.pushState null, 'furls', "#{document.location.pathname}#{search}"
    @  # for chaining

module?.exports = Furls
window?.Furls = Furls
