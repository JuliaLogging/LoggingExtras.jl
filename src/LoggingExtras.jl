module LoggingExtras

using Base.CoreLogging:
    global_logger,
    LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel

import Base.CoreLogging:
    AbstractLogger, SimpleLogger,
    handle_message, shouldlog, min_enabled_level, catch_exceptions

export TeeLogger, TransformerLogger, FileLogger,
    ActiveFilteredLogger, EarlyFilteredLogger, MinLevelLogger,
    DatetimeRotatingFileLogger, FormatLogger

######
# Re export Logging.jl from stdlib 
# list is stable between julia 1.0 and 1.6
# https://github.com/JuliaLang/julia/blob/release-1.6/stdlib/Logging/src/Logging.jl#L32-L46
using Logging

export Logging, AbstractLogger, LogLevel, NullLogger,
    @debug, @info, @warn, @error, @logmsg,
    with_logger, current_logger, global_logger, disable_logging,
    SimpleLogger, ConsoleLogger

######
# Utilities for dealing with compositional loggers.
# Since the logging system itself will not engage its checks
# Once the first logger has started, any compositional logger needs to check
# before passing anything on.

# For checking child logger, need to check both `min_enabled_level` and `shouldlog`
function comp_shouldlog(logger, args...)
    level = first(args)
    min_enabled_level(logger) <= level && shouldlog(logger, args...)
end

# For checking if child logger will take the message you are sending
function comp_handle_message_check(logger, args...; kwargs...)
    level, message, _module, group, id, file, line = args
    return comp_shouldlog(logger, level, _module, group, id)
end
###############################

include("tee.jl")
include("transformer.jl")
include("activefiltered.jl")
include("earlyfiltered.jl")
include("minlevelfiltered.jl")
include("filelogger.jl")
include("formatlogger.jl")
include("datetime_rotation.jl")
include("deprecated.jl")

end # module
