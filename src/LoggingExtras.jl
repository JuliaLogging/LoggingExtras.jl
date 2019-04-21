module LoggingExtras

using Base.CoreLogging:
    global_logger,
    LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel

import Base.CoreLogging:
    AbstractLogger, SimpleLogger,
    handle_message, shouldlog, min_enabled_level, catch_exceptions

export demux_global_logger,
    DemuxLogger, TransformerLogger, FileLogger,
    ActiveFilteredLogger, EarlyFilteredLogger, MinLevelLogger


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

include("demux.jl")
include("transformer.jl")
include("activefiltered.jl")
include("earlyfiltered.jl")
include("minlevelfiltered.jl")
include("filelogger.jl")

end # module
