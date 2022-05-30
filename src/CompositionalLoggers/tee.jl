struct TeeLogger{T<:NTuple{<:Any, AbstractLogger}} <: AbstractLogger
    loggers::T
end



"""
    TeeLogger(loggers...)

Send the same log message to all the loggers.

To include the current logger do:
`TeeLogger(current_logger(), loggers...)`
to include the global logger, do:
`TeeLogger(global_logger(), loggers...)`
"""
function TeeLogger(loggers::Vararg{AbstractLogger})
    return TeeLogger(loggers)
end

function handle_message(demux::TeeLogger, args...; kwargs...)
    for logger in demux.loggers
        if comp_handle_message_check(logger, args...; kwargs...)
            handle_message(logger, args...; kwargs...)
        end
    end
end

function shouldlog(demux::TeeLogger, args...)
    any(comp_shouldlog(logger, args...) for logger in demux.loggers)
end

function min_enabled_level(demux::TeeLogger)
    minimum(min_enabled_level(logger) for logger in demux.loggers)
end

function catch_exceptions(demux::TeeLogger)
    any(catch_exceptions(logger) for logger in demux.loggers)
end
