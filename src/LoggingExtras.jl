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

include("common.jl")

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
