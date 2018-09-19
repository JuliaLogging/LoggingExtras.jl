struct FileLogger <: AbstractLogger
	logger::SimpleLogger
	function FileLogger(path, level=Info; append=false)
		filehandle = open(path, append ? "a" : "w")
		this = new(SimpleLogger(filehandle, level))
		finalizer(this) do this
			close(filehandle)
		end
	end
end


function handle_message(filelogger::FileLogger, level, message, _module, group, id, file, line; kwargs...)
	handle_message(filelogger.logger, level, message, _module, group, id, file, line; kwargs...)
end
shouldlog(filelogger::FileLogger, level, _module, group, id) = shouldlog(filelogger.logger, level, _module, group, id)
min_enabled_level(filelogger::FileLogger) = min_enabled_level(filelogger.logger)
catch_exceptions(filelogger::FileLogger) = catch_exceptions(filelogger.logger)
