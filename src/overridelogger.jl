struct LevelOverrideLogger{T <: AbstractLogger} <: AbstractLogger
    level::LogLevel
    logger::T
end


handle_message(logger::LevelOverrideLogger, args...; kwargs...) =
    handle_message(logger.logger, args...; kwargs...)

function shouldlog(logger::LevelOverrideLogger, level, args...)
    level >= logger.level && shouldlog(logger.logger, level, args...)
end

min_enabled_level(logger::LevelOverrideLogger) = logger.level
catch_exceptions(logger::LevelOverrideLogger) = catch_exceptions(logger.logger)
