"""
    TransformerLogger(f, logger)
Preprocesses log messages, using the function `f`, before passing them to the
`logger` that is wrapped.
This can be used, for example, to truncate a log message.
to conditionally change the log level of logs from a given module
(which depending on the wrappped `logger`, might cause the message to be dropped).

The transforming function `f` is given a named tuple with the fields:
`(level, message, _module, group, id, file, line, kwargs)`
and should return the same.
See [`LoggingExtras.handle_message_args`](@ref) for more information on what each is.
"""
struct TransformerLogger{T<:AbstractLogger, F} <: AbstractLogger
    transform::F
    logger::T
end


function handle_message(transformer::TransformerLogger, args...; kwargs...)
    log_args = handle_message_args(args...; kwargs...)
    new_log_args = transformer.transform(log_args)

    args = Tuple(new_log_args)[1:end-1]
    kwargs = new_log_args.kwargs

    if comp_handle_message_check(transformer.logger, args...; kwargs...)
        handle_message(transformer.logger, args...; kwargs...)
    end
end

shouldlog(transformer::TransformerLogger, args...) = true

min_enabled_level(transformer::TransformerLogger) = BelowMinLevel

catch_exceptions(transformer::TransformerLogger) = catch_exceptions(transformer.logger)
