"""
    MinLevelLogger(logger, min_enabled_level)

Wraps `logger` in an filter that runs before the log message is created.
In many ways this is just a specialised [`EarlyFilteredLogger`](@ref)
that only checks the level.
This filter only allowed messages on or above the `min_enabled_level` to pass.
"""
struct MinLevelLogger{T <: AbstractLogger, L} <: AbstractLogger
    logger::T
    min_level::L
end


function handle_message(logger::MinLevelLogger, args...; kwargs...)
    if comp_handle_message_check(logger.logger, args...; kwargs...)
        return handle_message(logger.logger, args...; kwargs...)
    end
end

function shouldlog(logger::MinLevelLogger, args...)
    return comp_shouldlog(logger.logger, args...)
end

function min_enabled_level(logger::MinLevelLogger)
    comp_min_level = min_enabled_level(logger.logger)
    # `max` since if either would not take it then do not enable
    return max(logger.min_level, comp_min_level)
end

catch_exceptions(logger::MinLevelLogger) = catch_exceptions(logger.logger)
