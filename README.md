# LoggingExtras

[![Build Status](https://travis-ci.org/oxinabox/LoggingExtras.jl.svg?branch=master)](https://travis-ci.org/oxinabox/LoggingExtras.jl)

[![codecov.io](http://codecov.io/github/oxinabox/LoggingExtras.jl/coverage.svg?branch=master)](http://codecov.io/github/oxinabox/LoggingExtras.jl?branch=master)

![Diagram showing how loggers connect](diag.svg)

# Discussion: Compositional Loggers

LoggingExtras is designs around allowing you to build arbitrarily complicated
systems for "log plumbing". That is to say basically routing logged information to different places.
It is built around the idea of simple parts which are composed together,
to allow for powerful and flexible definition of your logging system.
Without having to define any custom loggers by subtyping `AbstractLogger`.
When we talk about composability we mean to say that the composition of any set of Loggers is itself a Logger.
LoggingExtras is a composable logging system.

Loggers can be broken down into 4 types:
 - *Sinks*: Sinks are the final end point of a log messages journey. They write it to file, or display it on the console, or set off a red flashing light in the laboratory. A Sink should never decide what to accept, only what to do with it.
 - *Filters*: Filters wrap around other loggers and decide wether or not to pass on a message. Thery can further be broken down by when that decision occurs (See `ActiveFilteredLogger` vs `EarlyFilteredLogger`).
 - *Transformers*: Transformers modify the content of log messages, before passing them on. This includes the metadata like severity level. Unlike Filters they can't block a log message, but they could drop its level down to say `Debug` so that normally noone would see it.
 - *Demux*: There is only one possible Demux Logger. and it is central to log routing. It acts as a hub that recieves 1 log message, and then sends copies of it to all its child loggers. Like iin the diagram above, it can be composed with Filters to control what goes where.

This is a basically full taxonomy of all compositional loggers.
Other than `Sinks`, this package implements the full set. So you shouldn't need to build your own routing components, just configure the ones included in this package.

It is worth understanding the idea of logging purity.
The loggers defined in this package are all pure.
The Filters, only filter, the Sinks only sink, the transformers only Transform.

We can contrast this to the the `ConsoleLogger` (the standard logger in the REPL).
The `ConsoleLogger` is an impure sink.
As well as displaying logs to the user (as a Sink);
it uses the log content, in the form of the `max_log` kwarg to decide if a log should be displayed (Active Filtering);
and it has a min_enabled_level setting, that controls if it will accept a message at all
(Early Filtering, in particular see `MinLevelLogger`).
If it was to be defined in a compositional way,
we would write something along the lines of:
```
ConsoleLogger(stream, min_level) =
    MinLevelLogger(
        ActiveFilteredLogger(max_log_filter,
            PureConsoleLogger(stream)
        ),
        min_level
    )
```


# Usage
Load the package with `using LoggingExtras`.
You likely also want to load the `Logging` standard lib.
Loggers can be constructed and used like normal.


### Basics of working with loggers
For full details, see the [Julia documentation on Logging](https://docs.julialang.org/en/v1/stdlib/Logging/index.html)

To use a `logger` in a given scope do
```
with_logger(logger) do
    #things
end
```

To make a logger the global logger, use
```
global_logger(logger)
```

to get the current global logger, use
```
logger = global_logger()
```

# Loggers introduced by this package:
This package introduces 6 new loggers.
The `DemuxLogger`, the `TransformerLogger`, 3 types of filtered logger, and the `FileLogger`.
All of them just wrap existing loggers.
 - The `DemuxLogger` sends the logs to multiple different loggers.
 - The `TransformerLogger` applies a function to modify log messages before passing them on.
 - The 3 filter loggers are used to control if a message is written or not
     - The `MinLevelLogger` only allowes messages to pass that are above a given level of severity
     - The `EarlyFilteredLogger` lets you write filter rules based on the `level`, `module`, `group` and `id` of the log message
     - The `ActiveFilteredLogger` lets you filter based on the full content
 - The `FileLogger` is a simple logger sink that writes to file.

By combining `DemuxLogger` with filter loggers you can arbitrarily route log messages, wherever you want.


## `DemuxLogger`

The `DemuxLogger` sends the log messages to multiple places.
It takes a list of loggers.
It also has the keyword argument `include_current_global`,
to determine if you also want to log to the global logger.

It is up to those loggers to determine if they will accept it.
Which they do using their methods for `shouldlog` and `min_enabled_level`.
Or you can do, by wrapping them in a filtered logger  as discussed below.

## `FileLogger`
The `FileLogger` does logging to file.
It is just a convience wrapper around the base julia `SimpleLogger`,
to make it easier to pass in a filename, rather than a stream.
It is really simple.
 - It takes a filename,
 - a kwarg to check if should `always_flush` (default: `true`).
 - a kwarg to `append` rather than overwrite (default `false`. i.e. overwrite by default)
The resulting file format is similar to that which is shown in the REPL.
(Not identical, but similar)

### Demo: `DemuxLogger` and `FileLogger`
We are going to log info and above to one file,
and warnings and above to another.

```
julia> using Logging; using LoggingExtras;

julia> demux_logger = DemuxLogger(
    MinLevelLogger(FileLogger("info.log"), Logging.Info),
    MinLevelLogger(FileLogger("warn.log"), Logging.Warn),
    include_current_global=false
);


julia> with_logger(demux_logger) do
    @warn("It is bad")
    @info("normal stuff")
    @error("THE WORSE THING")
    @debug("it is chill")
end

shell>  cat warn.log
┌ Warning: It is bad
└ @ Main REPL[34]:2
┌ Error: THE WORSE THING
└ @ Main REPL[34]:4

shell>  cat info.log
┌ Warning: It is bad
└ @ Main REPL[34]:2
┌ Info: normal stuff
└ @ Main REPL[34]:3
┌ Error: THE WORSE THING
└ @ Main REPL[34]:4
```

## `ActiveFilteredLogger`

The `ActiveFilteredLogger` exists to give more control over which messages should be logged.
It warps any logger, and before sending messages to the logger to log,
checks them against a filter function.
The filter function takes the full set of parameters of the message.
(See it's docstring with `?ActiveFilteredLogger` for more details.)

### Demo
We want to filter to only log strings staring with `"Yo Dawg!"`.

```
julia> function yodawg_filter(log_args)
    startswith(log_args.message, "Yo Dawg!")
end
 yodawg_filter (generic function with 1 method)

julia> filtered_logger = ActiveFilteredLogger(yodawg_filter, global_logger());

julia> with_logger(filtered_logger) do
    @info "Boring message"
    @warn "Yo Dawg! it is bad"
    @info "Another boring message"
    @info "Yo Dawg! it is all good"
end
┌ Warning: Yo Dawg! it is bad
└ @ Main REPL[28]:3
[ Info: Yo Dawg! it is all good
```

## `EarlyFilteredLogger`

The `EarlyFilteredLogger` is similar to the `ActiveFilteredLogger`,
but it runs earlier in the logging pipeline.
In particular it runs before the message is computed.
It can be useful to filter things early if creating the log message is expensive.
E.g. if it includes summary statistics of the error.
The filter function for early filter logging only has access to the
`level`, `_module`, `id` and `group` fields of the log message.
The most notable use of it is to filter based on modules,
see the HTTP example below.

Another example is using them to stop messages every being repeated within a given time period.

```
using Dates, Logging, LoggingExtras

julia> function make_throttled_logger(period)
    history = Dict{Symbol, DateTime}()
    # We are going to use a closure
    EarlyFilteredLogger(global_logger()) do log
        if !haskey(history, log.id) || (period < now() - history[log.id])
            # then we will log it, and update record of when we did
            history[log.id] = now()
            return true
        else
            return false
        end
    end
end
make_throttled_logger (generic function with 1 method)

julia> throttled_logger = make_throttled_logger(Second(3));

julia> with_logger(throttled_logger) do
    for ii in 1:10
        sleep(1)
        @info "It happened" ii
    end
end
┌ Info: It happened
└   ii = 1
┌ Info: It happened
└   ii = 4
┌ Info: It happened
└   ii = 7
┌ Info: It happened
└   ii = 10
```

## `MinLevelLogger`
This is basically a special case of the early filtered logger,
that just checks if the level of the message is above the level specified when it was created.

## `TransformerLogger`
The transformer logger allows for the modification of log messages.
This modification includes such things as its log level, and content,
and all the other arguments passed to `handle_message`.

When constructing a `TransformerLogger` you pass in a tranformation function,
and a logger to be wrapped.
The  transformation function takes a named tuple containing all the log message fields,
and should return a new modified named tuple.

A simple example of its use is truncating messages.

```
julia> using Logging, LoggingExtras

julia> truncating_logger  = TransformerLogger(global_logger()) do log
    if length(log.message) > 128
        short_message = log.message[1:min(end, 125)] * "..."
        return merge(log, (;message=short_message))
    else
        return log
    end
end;

julia> with_logger(truncating_logger) do
    @info "the truncating logger only truncates long messages"
    @info "Like this one that is this is a long and rambling message, it just keeps going and going and going,  and it seems like it will never end."
    @info "Not like this one, that is is short"
end
[ Info: the truncating logger only truncates long messages
[ Info: Like this one that is this is a long and rambling message, it just keeps going and going and going,  and it seems like it wil...
[ Info: Not like this one, that is is short
```

It can also be used to do things such as change the log level of messages from a particular module (see the example below).
Or to set common properties for all log messages within the `with_logger` block,
for example to set them all to the same `group`.

# More Examples

## Filter out any overly long messages

```
using LoggingExtras
using Logging

function sensible_message_filter(log)
    length(log.message) < 1028
end

global_logger(ActiveFilteredLogger(sensible_message_filter, global_logger()))
```


## Filterout any messages from HTTP

```
using LoggingExtras
using Logging
using HTTP

function not_HTTP_message_filter(log)
    log._module != HTTP
end

global_logger(EarlyFilteredLogger(not_HTTP_message_filter, global_logger()))
```

## Raising HTTP debug level errors to be Info level

```
using LoggingExtras
using Logging
using HTTP

transformer_logger(global_logger()) do log
    if log._module == HTTP && log.level=Logging.Debug
        # Merge can be used to construct a new NamedTuple
        # which effectively is the overwriting of fields of a NamedTuple
        return merge(log, (; level=Logging.Info))
    else
        return log
    end
end

global_logger(transformer_logger)
```
