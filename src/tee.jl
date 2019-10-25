abstract type AbstractTeeLogger <: AbstractLogger end

struct TeeLogger{T<:NTuple{<:Any, AbstractLogger}} <: AbstractTeeLogger
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

function shouldlog(demux::AbstractTeeLogger, args...)
    any(comp_shouldlog(logger, args...) for logger in demux.loggers)
end

function min_enabled_level(demux::AbstractTeeLogger)
    minimum(min_enabled_level(logger) for logger in demux.loggers)
end

function catch_exceptions(demux::AbstractTeeLogger)
    any(catch_exceptions(logger) for logger in demux.loggers)
end


struct FirstMatchLogger{T<:NTuple{<:Any,AbstractLogger}} <: AbstractTeeLogger
    loggers::T
end

"""
    FirstMatchLogger(loggers...)

For each log message, invoke the first logger in `loggers` that
matches with it; i.e., `min_enabled_level` is less than or equal to
the log level and `shouldlog` returns `true`.
"""
function FirstMatchLogger(loggers::Vararg{AbstractLogger})
    return FirstMatchLogger(loggers)
end

function handle_message(logger::FirstMatchLogger, args...; kwargs...)
    for logger in logger.loggers
        if comp_handle_message_check(logger, args...; kwargs...)
            return handle_message(logger, args...; kwargs...)
        end
    end
end
