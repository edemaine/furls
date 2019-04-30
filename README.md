# furls: Synchronize form state (and other state) with URL

## Basic Usage

Include `<script src="furls.js">` to define a global `window.Furls`,
or if you're using a build system supporting modules via `require`,
use `Furls = require('furls')`.

CoffeeScript:

```coffee
update = (changed) ->
  ## @ is the furls instance
  if changed.foo
    console.log "foo changed from #{changed.foo.oldValue} to #{changed.foo.value}"
  for key, value of @getState()  # mapping of ids to values
    console "#{key} is currently #{value}"

furls = new Furls()        # create input handler
.addInputs()               # auto-add all inputs
.on 'stateChange', update  # call update(changed) when any input changes
.syncState()               # auto-keep URL's search in sync with form state
```

## API

`Furls` objects supports the following API:

### Inputs

`<input>` elements can generally be specified by string ID, DOM element,
or Furls' internal representation of the input (see below).

* `.addInput(input)`: Start tracking the specified input.
* `.addInputs(query = 'input, textarea')`: Start tracking all inputs matching
  the specified query selector (a valid input to `document.querySelectorAll`).
  The default `query` includes all `<input>` and `<textarea>` elements
  in the document.
* `.clearInputs()`: Stop tracking all inputs.
* `.set(input, value)`: Set the value of `input` to `value` as if the user
  did, triggering change events if appropriate.  (Note that manually setting
  a DOM's `value` attribute does *not* trigger events, so use this instead.)
* `.maybeChange(input)`: Check whether the value of `input` has changed,
  and trigger change events if appropriate.  (In case the DOM's `value`
  attribute changed manually without calling `.set`.)
* `.find(input)`: Get the internal representation of the specified input.

### States

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
* `.getState()`: Return object `state` with attribute `state[id]` for
  each input with ID `id` equal to the value of the input
  (from the `checked` or `value` attribute).
* `.getSearch()`: Return state in URL search format (`?key=value&...`).
* `.getRelativeURL`: Return URL to self (`document.location.pathname`)
  with search given by `.getSearch()`.

### Events

* `.on(event, listener)`: Call `listener` when `event` occurs.
* `.off(event, listener)`: Stop calling `listener` when `event` occurs.
* `.trigger(event, ...)`: Force `event` to occur with specified arguments.
  (You probably shouldn't need this.)

There are currently three types of events that occur:

* `inputChange`: An input changed in value.  (Null changes don't count.)
  Argument is the internal representation of the input (see below).
* `stateChange`: One or more inputs changed in value, aggregating together
  potentially several `inputChange` events`.
  (Null changes don't count.)  Argument is an object `changed`
  with an attribute `changed[id]` for each changed input having ID `id`,
  giving the internal representation of the input (see below).

### Inputs

The internal representation of an input is an object with (at least)
the following attributes:

* `.id`: String ID of the `<input>` element
* `.dom`: The DOM object of the `<input>` element
* `.defaultValue`: The specified default value of the `<input>` element
  (from the `defaultChecked` or `defaultValue` attribute)
* `.value`: Current value of the `<input>` element
  (from the `checked` or `value` attribute)
* `.oldValue`: The previous value of the `<input>` element
  (in particular during change events)
