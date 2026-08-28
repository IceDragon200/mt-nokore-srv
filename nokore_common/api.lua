--- @namespace nokore_common

--- Utility function for creating a callbacks table, note the returned callbacks table only
--- has references to the original `order` and `registered` tables, replace them in the
--- callbacks table will have no effect on the functions.
---
--- @since "1.1.0"
--- @spec new_callbacks(): Table
function nokore_common.new_callbacks()
  local i = 0
  local order = {}
  local registered = {}
  local callbacks = {
    order = order,
    registered = registered,
  }

  --- Register a new unique callback by name.
  --- Callbacks that already exist with the same name will throw an error.
  --- @spec register(name: String, callback: Function): void
  function callbacks.register(name, callback)
    if type(name) ~= "string" then
      error("expected name to be a string")
    end
    if type(callback) ~= "function" then
      error("expected callback to be a function")
    end
    if registered[name] then
      error("callback already exists for name=" .. name)
    end
    registered[name] = callback
    i = i + 1
    order[i] = name
  end

  --- Executes the callbacks in the order they were registered without arguments.
  --- @spec ordered_exec0(): void
  function callbacks.ordered_exec0()
    for _,name in pairs(order) do
      registered[name]()
    end
  end

  --- Executes the callbacks in the order they were registered with 1 argument.
  --- @spec ordered_exec1(arg1: Any): void
  function callbacks.ordered_exec1(arg1)
    for _,name in pairs(order) do
      registered[name](arg1)
    end
  end

  --- Executes the callbacks in the order they were registered with 2 arguments.
  --- @spec ordered_exec2(arg1: Any, arg2: Any): void
  function callbacks.ordered_exec2(arg1, arg2)
    for _,name in pairs(order) do
      registered[name](arg1, arg2)
    end
  end

  --- Executes the callbacks in the order they were registered with 3 arguments.
  --- @spec ordered_exec3(arg1: Any, arg2: Any, arg3: Any): void
  function callbacks.ordered_exec3(arg1, arg2, arg3)
    for _,name in pairs(order) do
      registered[name](arg1, arg2, arg3)
    end
  end

  --- Executes the callbacks in the order they were registered with arguments.
  --- @spec ordered_exec(): void
  function callbacks.ordered_exec(...)
    for _,name in pairs(order) do
      registered[name](...)
    end
  end

  --- Executes the callbacks by table order without arguments.
  --- @spec exec0(): void
  function callbacks.exec0()
    for name,callback in pairs(registered) do
      callback()
    end
  end

  --- Executes the callbacks by table order without arguments.
  --- @spec exec1(arg1: Any): void
  function callbacks.exec1(arg1)
    for name,callback in pairs(registered) do
      callback(arg1)
    end
  end

  --- Executes the callbacks by table order without arguments.
  --- @spec exec2(arg1: Any, arg2: Any): void
  function callbacks.exec2(arg1, arg2)
    for name,callback in pairs(registered) do
      callback(arg1, arg2)
    end
  end

  --- Executes the callbacks by table order without arguments.
  --- @spec exec3(arg1: Any, arg2: Any, arg3: Any): void
  function callbacks.exec3(arg1, arg2, arg3)
    for name,callback in pairs(registered) do
      callback(arg1, arg2, arg3)
    end
  end

  --- Executes the callbacks by table order with arguments.
  --- @spec exec(): void
  function callbacks.exec(...)
    for _name,callback in pairs(registered) do
      callback(...)
    end
  end

  return callbacks
end
