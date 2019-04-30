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
.syncState()               # auto-keep URL query in sync with form state
```

