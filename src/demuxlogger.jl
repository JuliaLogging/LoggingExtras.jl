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

function handle_message(demux::DemuxLogger, level, message, _module, group, id, file, line; kwargs...)
	for logger in demux.loggers
        if min_enabled_level(logger)<= level &&  shouldlog(logger,  level, _module, group, id)
            # we bypassed those checks above, so we got to check them for each
			handle_message(logger, level, message, _module, group, id, file, line; kwargs...)
		end
	end
end

function shouldlog(demux::DemuxLogger, level, _module, group, id)
	any(shouldlog(logger, level, _module, group, id) for logger in demux.loggers)
end

function min_enabled_level(demux::DemuxLogger)
	minimum(min_enabled_level(logger) for logger in demux.loggers)
end

function catch_exceptions(demux::DemuxLogger)
	any(catch_exceptions(logger) for logger in demux.loggers)
end
