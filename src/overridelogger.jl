"""
    LevelOverrideLogger(level, logger)

A logger that allows overriding the log level of a child level.
Useful in debugging scenarios, where it is desirable to ignore
the log level any other logger may have set.
"""
struct LevelOverrideLogger{T <: AbstractLogger} <: AbstractLogger
    level::LogLevel
    logger::T
end


handle_message(logger::LevelOverrideLogger, args...; kwargs...) =
    handle_message(logger.logger, args...; kwargs...)

function shouldlog(logger::LevelOverrideLogger, level, args...)
    # Ignore the logger.logger's own level and instead check the override level
    level >= logger.level && shouldlog(logger.logger, level, args...)
end

min_enabled_level(logger::LevelOverrideLogger) = logger.level
catch_exceptions(logger::LevelOverrideLogger) = catch_exceptions(logger.logger)
