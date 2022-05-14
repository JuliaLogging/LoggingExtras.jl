using Logging

import Base.CoreLogging: _min_enabled_level

export @debug2, @debug3, @debug4, Debug2, Debug3, Debug4, ModuleFilterLogger

const Debug2 = Debug - 1
const Debug3 = Debug - 2
const Debug4 = Debug - 3

debug_docs = """
    @debug2 message [key=value | value ...]
    @debug3 message [key=value | value ...]
    @debug4 message [key=value | value ...]

Debug-specific logging macros (similar to `@debug`) for increasing levels of verbosity; i.e.
`@debug2` is meant for debug logging slightly more verbose than `@debug`, and so on with
`@debug3` and `@debug4`. See [`LoggingExtras.@setupdebuglogging()`](@ref) for additional
information about how to conveniently enable these precision debug levels
for logging in specific modules.
"""

macro debug2(exs...); :(@logmsg Debug2 $(exs...)); end
macro debug3(exs...); :(@logmsg Debug3 $(exs...)); end
macro debug4(exs...); :(@logmsg Debug4 $(exs...)); end

@eval @doc $debug_docs :(@debug2)
@eval @doc $debug_docs :(@debug3)
@eval @doc $debug_docs :(@debug4)

"""
    ModuleFilterLogger(mod, level, logger)

Custom logger for controlling the log level of a specific module. Non-specified modules
should not be affected using this logger. All logs for the specified module will be filtered
on `level` by this logger before being passed to the child `logger`. See
`LoggingExtras.@setupdebuglogging()` for more information on how to allow using this
logger conveniently.
"""
struct ModuleFilterLogger{T <: AbstractLogger} <: AbstractLogger
    mod::Module
    level::LogLevel
    logger::T
end

Logging.handle_message(x::ModuleFilterLogger, args...; kw...) = 
    Logging.handle_message(x.logger, args...; kw...)

function Logging.shouldlog(x::ModuleFilterLogger, level, _module, args...; kw...)
    if x.mod == _module
        # i.e. this logger will handle ALL log filtering for a specific module
        return level >= x.level
    end
    # why the call to min_enabled_level here for child logger?
    # we're basically bypassing the core logging min_enabled_level check by
    # passing the min level of any loggers because we want to do the level check
    # *here* for the module-specific logger, but then also need to do the level check
    # for other loggers
    return level >= Logging.min_enabled_level(x.logger) && Logging.shouldlog(x.logger, level, _module, args...; kw...)
end

# we want the minimum of our module-specific level and any other loggers
Logging.min_enabled_level(x::ModuleFilterLogger, args...; kw...) =
    min(x.level, Logging.min_enabled_level(x.logger, args...; kw...))

Logging.catch_exceptions(x::ModuleFilterLogger, args...; kw...) = 
    Logging.catch_exceptions(x.logger, args...; kw...)

"""
    LoggingExtras.setmoduleloglevel!(mod, level)

Wrap the `global_logger()` with a [`ModuleFilterLogger`](@ref) for the specified `mod`.
Only logs in `mod` should be affected by this setting.
"""
function setmoduleloglevel!(mod::Module, level)
    _min_enabled_level[] = min(level, _min_enabled_level[])
    logger = global_logger()
    if logger isa ModuleFilterLogger
        if logger.mod == mod
            logger = logger.logger
        end
    end
    global_logger(ModuleFilterLogger(mod, level, logger))
    return
end

"""
    LoggingExtras.withmoduleloglevel(f, mod, level)

Like `with_logger`, but for specifying a log `level` for a specific module `mod`
while executing the function `f`.
"""
function withmoduleloglevel(@nospecialize(f), mod::Module, level)
    old_min_enabled_level = _min_enabled_level[]
    _min_enabled_level[] = min(level, _min_enabled_level[])
    try
        with_logger(ModuleFilterLogger(mod, level, current_logger())) do
            f()
        end
    finally
        _min_enabled_level[] = old_min_enabled_level
    end
end

"""
    LoggingExtras.@setupdebuglogging()

Macro that can be called at the top level in a module to define two convenience methods
for using [`ModuleFilterLogger`](@ref):
    * `MyModule.setloglevel!(level)`: sets the log level for just the specific module `MyModule`
    * `MyModule.withloglevel(f, level)`: sets the log level for just the specific module `MyModule`
        while executing the function `f`

Usage is like:
```julia
module MyModule

using LoggingExtras
LoggingExtras.@setupdebuglogging()

end
```

Which then allows using the conveninence methods like:
```julia
using MyModule

MyModule.setloglevel!(Debug) # set log level for MyModule to Debug

MyModule.setloglevel!(Debug2) # increase debug logging verbosity for MyModule

MyModule.withloglevel(Debug4) do
    # do stuff where maximum debug logging verbosity will be turned on
end
```
"""
macro setupdebuglogging()
    esc(quote
        setloglevel!(level) = LoggingExtras.setmoduleloglevel!(@__MODULE__, level)
        withloglevel(f, level) = LoggingExtras.withmoduleloglevel(f, @__MODULE__, level)
    end)
end
