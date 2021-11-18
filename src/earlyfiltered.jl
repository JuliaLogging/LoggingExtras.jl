"""
    EarlyFilteredLogger(filter, logger)

Wraps `logger` in an filter that runs before the log message is created.

For contrast see the [`ActiveFilteredLogger`](@ref) which has full control,
but runs after the log message content is computed.
In most circumstances this is fine, but if your log messages are expensive
to create (e.g. they include summary statistics), then the `EarlyFilteredLogger`
is going to be better.

The `filter` should be a function that returns a boolean.
`true` if the message should be logged and `false` if not.
As input it will be given a named tuple with the following fields:
`(level, _module, group, id)`
See [`LoggingExtras.shouldlog_args`](@ref) for more information on what each is.
"""
struct EarlyFilteredLogger{T <: AbstractLogger, F} <: AbstractLogger
    filter::F
    logger::T
end


function handle_message(logger::EarlyFilteredLogger, args...; kwargs...)
    if comp_handle_message_check(logger.logger, args...; kwargs...)
        return handle_message(logger.logger, args...; kwargs...)
    end
end

function shouldlog(logger::EarlyFilteredLogger, args...)
    log_args = shouldlog_args(args...)
    comp_shouldlog(logger.logger, args...) && logger.filter(log_args)
end

min_enabled_level(logger::EarlyFilteredLogger) = min_enabled_level(logger.logger)
catch_exceptions(logger::EarlyFilteredLogger) = catch_exceptions(logger.logger)

"""
    shouldlog_args

This returns a NamedTuple containing all the arguments the logger gives
to `shouldlog`
It is passed to the early logger filter.
These argument come from the logging macro (`@info`, `@warn` etc).

  * `level::LogLevel` Warn, Info, etc,
  * `_module::Module` can be used to specify a different originating module from
    the source location of the message.
  * `group::Symbol` can be used to override the message group (this is
    normally derived from the base name of the source file).
  * `id::Symbol` can be used to override the automatically generated unique
    message identifier.  This is useful if you need to very closely associate
    messages generated on different source lines.
"""
function shouldlog_args(fieldvals...)
    fieldnames = (:level, :_module, :group, :id)
    return NamedTuple{fieldnames, typeof(fieldvals)}(fieldvals)
end
