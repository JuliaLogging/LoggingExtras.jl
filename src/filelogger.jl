struct FileLogger <: AbstractLogger
    logger::SimpleLogger
    always_flush::Bool
end

function FileLogger(path; append=false, always_flush=true)
    filehandle = open(path, append ? "a" : "w")
    FileLogger(SimpleLogger(filehandle, BelowMinLevel), always_flush)
end


function handle_message(filelogger::FileLogger, args...; kwargs...)
    handle_message(filelogger.logger, args...; kwargs...)
    filelogger.always_flush && flush(filelogger.logger.stream)
end
shouldlog(filelogger::FileLogger, arg...) = true
min_enabled_level(filelogger::FileLogger) = BelowMinLevel
catch_exceptions(filelogger::FileLogger) = catch_exceptions(filelogger.logger)
