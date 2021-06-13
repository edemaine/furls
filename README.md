# furls: Synchronize form state (and other state) with URL

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
* `.findInput(input)`: Get the internal representation of the specified input.

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
* `.getState()`: Return object `state` with attribute `state[name]` for
  each input with that `name` equal to the value of the input
  (from the `checked` or `value` attribute).
  For each group of radio buttons, this object stores a single mapping from
  the group's `name` to the selected button's `value` (like HTML forms).
* `.getSearch()`: Return state in URL search format (`?key=value&...`).
* `.getRelativeURL`: Return URL to self (`document.location.pathname`)
  with search given by `.getSearch()`.

### Events

* `.on(event, listener)`: Call `listener` when `event` occurs.
* `.off(event, listener)`: Stop calling `listener` when `event` occurs.
* `.trigger(event, ...)`: Force `event` to occur with specified arguments.
  (You probably shouldn't need this.)

There are currently two types of events that occur:

* `inputChange`: An input changed in value.  (Null changes don't count.)
  Argument is the internal representation of the input (see below).
* `stateChange`: One or more inputs changed in value, aggregating together
  potentially several `inputChange` events (e.g. when loading from URL).
  (Null changes don't count.)  Argument is an object `changed`
  with an attribute `changed[name]` for each changed input with that `name`,
  giving the internal representation of the input (see below).
  When a radio button changes, `changed[name]` will be the newly selected
  radio button (excluding all other buttons with the same `name` i.e. group).

### Inputs

The internal representation of an input is an object with (at least)
the following attributes:

* `.id`: `id` attribute of the `<input>` element (should be unique)
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
* `.oldValue`: The previous value of the `<input>` element
  (in particular during change events)
