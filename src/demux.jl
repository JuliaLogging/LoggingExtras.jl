struct DemuxLogger <: AbstractLogger
    loggers::Vector{AbstractLogger}
end



"""
    DemuxLogger(loggers...; include_current=true)

Sets the global_logger to demux,
so that messages are sent to all the loggers.
If `include_current_global` is true, then messages are also sent to the global logger
(or rather to what was the global logger when this was constructed).
Normally this would be the ConsoleLogger in the REPL etc.
"""
function DemuxLogger(loggers::Vararg{AbstractLogger}; include_current_global=true)
    loggers = Vector{AbstractLogger}(collect(loggers))
    if include_current_global
        push!(loggers, global_logger())
    end
    DemuxLogger(loggers)
end

function handle_message(demux::DemuxLogger, args...; kwargs...)
    for logger in demux.loggers
        if comp_handle_message_check(logger, args...; kwargs...)
            handle_message(logger, args...; kwargs...)
        end
    end
end

function shouldlog(demux::DemuxLogger, args...)
    any(comp_shouldlog(logger, args...) for logger in demux.loggers)
end

function min_enabled_level(demux::DemuxLogger)
    minimum(min_enabled_level(logger) for logger in demux.loggers)
end

function catch_exceptions(demux::DemuxLogger)
    any(catch_exceptions(logger) for logger in demux.loggers)
end
