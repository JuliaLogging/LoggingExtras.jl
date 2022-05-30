"""
    ActiveFilteredLogger(filter, logger)

Wraps `logger` in an active filter.
While loggers intrinsictally have in built filtering mechanisms.
Wrapping it in a `ActiveFilterLogger` allows for extract control,
at the cost of a bit of overhead.

The `ActiveFilteredLogger` has full control of what is logged,
as it sees the full message,
this does mean however it determines what to log at runtime,
which is the source of the overhead.
The [`EarlyFilteredLogger`](@ref) has less control,
but decides if to log before the message is computed.

The `filter` should be a function that returns a boolean.
`true` if the message should be logged and `false` if not.
As input it will be given a named tuple with the following fields:
`(level, message, _module, group, id, file, line, kwargs)`
See [`LoggingExtras.handle_message_args`](@ref) for more information on what each is.
"""
struct ActiveFilteredLogger{T <: AbstractLogger, F} <: AbstractLogger
    filter::F
    logger::T
end


function handle_message(logger::ActiveFilteredLogger, args...; kwargs...)
    log_args = handle_message_args(args...; kwargs...)
    if comp_handle_message_check(logger.logger, args...; kwargs...)
        if logger.filter(log_args)
            handle_message(logger.logger, args...; kwargs...)
        end
    end
end

function shouldlog(logger::ActiveFilteredLogger, args...)
    return comp_shouldlog(logger.logger, args...)
end

min_enabled_level(logger::ActiveFilteredLogger) = min_enabled_level(logger.logger)
catch_exceptions(logger::ActiveFilteredLogger) = catch_exceptions(logger.logger)

"""
    handle_message_args

This creates NamedTuple containing all the arguments the logger gives
to `handle_message`
It is the type pased to the active logger filter.
These argument come from the logging macro (@info`, `@warn` etc).

  * `level::LogLevel` Warn, Info, etc,
  * `message::String` the message to be logged
  * `_module::Module` can be used to specify a different originating module from
    the source location of the message.
  * `group::Symbol` can be used to override the message group (this is
    normally derived from the base name of the source file).
  * `id::Symbol` can be used to override the automatically generated unique
    message identifier.  This is useful if you need to very closely associate
    messages generated on different source lines.
  * `file::String` and `line::Int` can be used to override the apparent
    source location of a log message.
  * `kwargs...`: Any  keyword or position arguments passed to the logging macro
"""
function handle_message_args(args...; kwargs...)
    fieldnames = (:level, :message, :_module, :group, :id, :file, :line, :kwargs)
    fieldvals = (args..., kwargs)
    return NamedTuple{fieldnames, typeof(fieldvals)}(fieldvals)
end
