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
    # unlike other CompositionalLoggers: No level check as we are ignoring the 
    # logger.loggers level and just using the overriden leven which has already been checked
    return shouldlog(logger.logger, level, args...)
end

min_enabled_level(logger::LevelOverrideLogger) = logger.level
catch_exceptions(logger::LevelOverrideLogger) = catch_exceptions(logger.logger)

#################################################################################
# Propagating the constructor down to places it is needed

# fallback case, not a logger we know about, assume it is a sink
propagate_level_override(level, sink) = LevelOverrideLogger(level, sink)


for L in (ActiveFilteredLogger, EarlyFilteredLogger,  TransformerLogger)
    @eval function propagate_level_override(level, logger::$L)
        # these loggers don't level filter on their own, just based on what they wrap
        # so just need to propagate on to what they wrapped
        return $L(getfield(logger, 1), propagate_level_override(level, logger.logger))
    end
end

function propagate_level_override(level, logger::MinLevelLogger)
    # override overpowers any MinLevelLogger so can drop that, and just propagate on to sink
    #TODO: CHECK ME is this right for both MinLevelLoggers that are higher and also that are lower?
    return propagate_level_override(level, logger.logger)
end

function propagate_level_override(level, logger::LevelOverrideLogger)
    # overriding the override: just use the new one, and propagate
    return LevelOverrideLogger(level, propagate_level_override(level, logger.logger))
end

function propagate_level_override(level, logger::TeeLogger)
    # We are going to propage through each of them, this is not unarguably the universal
    # the right choice, but it is consistent. For more control should construct directly
    new_backings = map(logger.loggers) do backing
        propagate_level_override(level, backing)
    end
    # The TeeLogger itself had no level control so doesn't need a wrapper
    return TeeLogger(new_backings)
end