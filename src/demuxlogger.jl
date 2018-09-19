struct DemuxLogger <: AbstractLogger
	loggers::Vector{AbstractLogger}
end

"""
	demux_global_logger!(loggers...; include_current=true)

Sets the global_logger to demux,
so that messages are sent to all the loggers.
If `include_current` is true, then messages are also sent to the old global logger.
Normally this would be the ConsoleLogger in the REPL etc.
"""
function demux_global_logger!(loggers...; include_current=true)
	loggers = collect(loggers)
	if include_current
		push!(loggers, global_logger())
	end
	global_logger(DemuxLogger(loggers))
end

function handle_message(demux::demux, level, message, _module, group, id, file, line; kwargs...)
	for logger in demux.loggers
		if shouldlog(logger,  level, _module, group, id)
			handle_message(logger, level, message, _module, group, id, file, line; kwargs...)
		end
	end
end

function shouldlog(demux::demux, level, _module, group, id)
	any(shouldlog(logger, level, _module, group, id) for logger in demux.loggers)
end

function min_enabled_level(demux::demux)
	minimum(min_enabled_level(logger) for logger in demux.loggers)
end

function catch_exceptions(demux::demux)
	any(catch_exceptions(logger) for logger in demux.loggers)
end
