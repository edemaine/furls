# furls: Synchronize form state (and other state) with URL

The furls library makes it easy to synchronize form state (e.g. checkboxes,
radio buttons, and text/textarea inputs) with the query part of the page's URL.
This makes it easy to bookmark/share/link the current state of a web app, and
makes the browser's back button act as an undo action.
The library can also synchronize the classes of a particular element to
represent the form state, making it easy to customize styles in response to
form state.
For examples of furls in action, see
[the font-webapp library](https://github.com/edemaine/font-webapp)
which builds upon it.

## Basic Usage

To define a global `window.Furls`, include `<script src="furls.js"></script>`
in your HTML, via either:

* Local `npm install furls` and use
 `<script src="node_modules/furls/furls.js></script>`
* CDN `<script src="https://cdn.jsdelivr.net/npm/furls/furls.js"></script>`

If you're using a build system supporting NPM modules via `require`,
use `Furls = require('furls')`.

Simple example of usage in [CoffeeScript](https://coffeescript.org):

```coffee
update = (changed) ->
  ## @ is the furls instance
  if changed.foo
    console.log "foo changed from #{changed.foo.oldValue} to #{changed.foo.value}"
  for name, value of @getState()  # mapping of names/ids to values
    console.log "#{name} is currently #{value}"

furls = new Furls()        # create input handler
.addInputs()               # auto-add all inputs
.on 'stateChange', update  # call update(changed) when any input changes
.syncState()               # auto-keep URL's search in sync with form state
.syncClass()               # auto-keep <html>'s class in sync with form state
```

## API

`Furls` objects supports the following API:

### Inputs

`<input>` elements can generally be specified by string ID, DOM element,
or furls' internal representation of the input (see below).

* `.addInputs(query = 'input, select, textarea')`:
  Start tracking all inputs matching the specified query selector
  (a valid input to `document.querySelectorAll`).
  The default `query` includes all `<input>`, `<select>`, and `<textarea>`
  elements in the document.
* `.configInput(input, options)`: Modify the `encode` and `decode` methods,
  or `minor` attribute, as described under [Input Objects](#input-objects),
  for an already added input.  Useful after bulk `.addInputs()`
  to configure a specific input.
* `.addInput(input, options = {})`: Start tracking the specified input.
  Optionally, you can specify manual `encode` and `decode` methods,
  or `minor` attribute, as described under [Input Objects](#input-objects).
  Degenerates to `.configInput` if `input` is already tracked.
* `.removeInput(input)`: Stop tracking the specified input.
* `.removeInputs(query)`: Stop tracking all matching inputs.
  Sometimes it's easier to specify what not to track than what to track.
* `.clearInputs()`: Stop tracking all inputs.
* `.get(input)`: Get the value of `input` (as convenient short-hand).
* `.set(input, value)`: Set the value of `input` to `value` as if the user
  did, triggering change events if appropriate.  (Note that manually setting
  a DOM's `value` attribute does *not* trigger events, so use this instead.)
* `.maybeChange(input)`: Check whether the value of `input` has changed,
  and trigger change events if appropriate.  (In case the DOM's `value`
  attribute changed manually without calling `.set`.)
* `.findInput(input)`: Get the internal representation of the specified input.
* `.getInputEvents(input)`: Returns which events to monitor for input `input`.
  Defaults to `['input', 'change']`, which should cover all input types on all
  browsers, but you could override this function to listen for custom DOM
  events.  Redundant events are coalesced so they generate only one furls
  `inputChange` events.

### States / URL Synchronization

* `.syncState(history = 'push', loadNow = true)`: Automatically keep the
  document's URL's search component in sync with the state of the inputs.
  When a form changes input, the new URL either gets "pushed" (when `history`
  is `'push'`, so the back button returns to the previous state) or
  "replaced" (when `history` is `'replace'`, so the back button leaves the
  page).  See [the difference between `pushState` and
  `replaceState`](https://developer.mozilla.org/en-US/docs/Web/API/History_API).
  `loadNow` specifies whether to immediately set the inputs' state according
  to the current URL's search component (default `true`).
* `.loadURL(url = document.location, trigger = true)`: Manually set the
  inputs' state according to `url`'s search component, and trigger change
  events if `trigger` is `true` (default yes).  If you've called `.syncState`,
  this gets automatically called during `popstate` events, but this can be
  useful if you want to load a stored state of some kind.
* `.setURL(history = 'push', force = false)`: Manually set the document's
  URL's search component to match the state of the inputs.  `history` can be
  `push` or `replace` as in `.syncState()`.  If you want to push the current
  state even if the state hasn't changed, set `force` to `true`.
* `.getState()`: Return object `state` with attribute `state[name]` for
  each input with that `name` equal to the value of the input
  (from the `checked` or `value` attribute).
  For each group of radio buttons, this object stores a single mapping from
  the group's `name` to the selected button's `value` (like HTML forms).
* `.getSearch()`: Return state in URL search format (`?key=value&...`).
* `.getRelativeURL`: Return URL to self (`document.location.pathname`)
  with search given by `.getSearch()`.

## Class Synchronization

* `.syncClass(query = ':root', prefix = '', updateNow = true)`:
  Synchronizes the `classList` of the specified DOM `query` (which can also
  be just a DOM element or an array of DOM elements) to match the state of
  all "discrete" tracked inputs.  Classes are of the form `NAME-VALUE`,
  prefixed by `prefix`; for example, a checkbox with name `box` can be tested
  with CSS queries `.box-true` and `.box-false`.
* `.discreteValue(input)`: Returns whether the given input has a "discrete"
  value, and thus `.syncClass` will synchronize its class.
  By default, this includes all inputs of type `"checkbox"` and `"radio"`,
  but you could override it to include a different subset of inputs.

### Events

* `.on(event, listener)`: Call `listener` when `event` occurs.
* `.off(event, listener)`: Stop calling `listener` when `event` occurs.
* `.trigger(event, ...)`: Force `event` to occur with specified arguments.
  (You probably shouldn't need this.)

There are currently three types of events that occur:

* `'inputChange'`: An input changed in value.  (Null changes don't count.)
  Argument is the internal representation of the input (see below).
* `'stateChange'`: One or more inputs changed in value, aggregating together
  potentially several `'inputChange'` events (e.g. when loading from URL).
  (Null changes don't count.)  Argument is an object `changed`
  with an attribute `changed[name]` for each changed input with that `name`,
  giving the internal representation of the input (see below).
  When a radio button changes, `changed[name]` will be the newly selected
  radio button (excluding all other buttons with the same `name` i.e. group).
  Triggered after individual `inputChange` events.
* `'loadURL'`: All input values were just loaded from the URL (caused by
  `syncState` from browser navigation or initial loading on startup, or
  from calling `loadURL` manually).  Argument is the URL's search component.
  Trigger after `inputChange` and `stateChange` events.

### Helpers

You're unlikely to need these functions, unless you're being clever.
You can override them, however, to get custom behaviors.

* `getParameterByName(name, search = window.location.search)`:
  Returns the value from any `name=value` in the specified URL search string.
  In most cases, you should use `loadURL` which calls this repeatedly.
* `getInputValue(input)`: Given an `input` object, computes its current
  `value` in the format described under [Input Objects](#input-objects).
  In most cases, you should use `.get` to get the current value.
* `getInputDefaultValue(input)`: Given an `input` object, computes its
  default `value` in the format described under [Input Objects](#input-objects).
  In most cases, you should use `.findInput` and `.defaultValue`.
* `setInputValue(input, value)`: Given an `input` object, sets its `value`
  according to a given value in the format described under
  [Input Objects](#input-objects), without triggering any events.
  In most cases, you should use `.set` to set the value of an input,
  which also triggers the relevant events.
* `queueMicrotask(task)`: Schedules to call `task` before next browser render,
  if [`window.queueMicrotask`](https://developer.mozilla.org/en-US/docs/Web/API/queueMicrotask)
  is available.  As a fallback, runs `task` after the next browser render
  via `setTimeout(task, 0)`.

### Input Objects

The internal representation of an input (as returned by e.g. `findInput`)
is an object with (at least) the following attributes:

* `.id`: `id` attribute of the `<input>` element (should be unique)
* `.type`: `type` attribute of the `<input>` element, or `"textarea"`
  in the case of `<textarea>` elements.
* `.name`: `name` attribute of the `<input>` element, or else its `id`
  (differs from `id` for radio buttons, where `name` defines groups).
  This is the key for the state object returned by `.getState()`,
  and what ends up in the URL.
* `.dom`: The DOM object of the `<input>` element
* `.defaultValue`: The specified default value of the `<input>` element
  (from the `defaultChecked` or `defaultValue` attribute)
* `.value`: Current value of the `<input>` element
  (from the `checked` or `value` attribute).
  For checkboxes, this is `true` or `false`.
  For radio buttons, this is the `value` attribute if selected, and
  `undefined` if not selected.
  For `type=number` and `type=range` inputs, this is automatically parsed
  into a `Number`.
  For `<select multiple>`, this is an array of `<option>` value strings;
  for a single-value `<select>`, this is a single `<option>` value string.
* `.oldValue`: The previous value of the `<input>` element
  (in particular during change events)

In addition, you can add the following attributes, via `configInput` or
when calling `addInput`:

* `.encode(value)`: Encode the specified value into a string for the URL.
  For example, you can reduce number precision, or replace characters
  that encode verbosely into characters that encode more succinctly.
  Don't worry about URL encoding; whatever you return will be further
  encoded via `encodeURIComponent` and mapping space to `+`.
  This method gets called with `this` set to the input object.
* `.decode(value)`: Decode the specified string encoding from the URL into a
  value for this input.
  For example, you can undo character encodings you did in `.encode`.
  If your `.encode` doesn't need special decoding (e.g. it reduced number
  precision), then you don't need to specify `.decode`.
  Don't worry about URL encoding; the `value` argument will already be
  decoded via `decodeURIComponent` and mapping `+` to space.
  This method gets called with `this` set to the input object.
* `.minor`: Boolean specifying whether changes to this input should be
  considered "minor".  If all changed fields are minor, then the `history`
  mode is forced to be `'replace'`.
