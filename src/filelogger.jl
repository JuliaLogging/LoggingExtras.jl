# TODO: Maybe this should just be a function
# It is a super thing wrapper around a SimpleLogger


struct FileLogger <: AbstractLogger
	logger::SimpleLogger
    always_flush::Bool
end

function FileLogger(path::AbstractString; min_level=Info, append=false, always_flush=true)
    filehandle = open(path, append ? "a" : "w")
    FileLogger(SimpleLogger(filehandle, min_level), always_flush)
end


function handle_message(filelogger::FileLogger, level, message, _module, group, id, file, line; kwargs...)
	handle_message(filelogger.logger, level, message, _module, group, id, file, line; kwargs...)
    filelogger.always_flush && flush(filelogger.logger.stream)
end
shouldlog(filelogger::FileLogger, level, _module, group, id) = shouldlog(filelogger.logger, level, _module, group, id)
min_enabled_level(filelogger::FileLogger) = min_enabled_level(filelogger.logger)
catch_exceptions(filelogger::FileLogger) = catch_exceptions(filelogger.logger)
