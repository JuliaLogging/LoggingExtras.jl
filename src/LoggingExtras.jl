module LoggingExtras

using Base.CoreLogging:
    global_logger,
    LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel

import Base.CoreLogging:
    AbstractLogger, SimpleLogger,
    handle_message, shouldlog, min_enabled_level, catch_exceptions

export TeeLogger, TransformerLogger, FileLogger,
    ActiveFilteredLogger, EarlyFilteredLogger, MinLevelLogger,
    DatetimeRotatingFileLogger, FormatLogger, LevelOverrideLogger,
    @debugv, @infov, @warnv, @errorv, @logmsgv

######
# Re export Logging.jl from stdlib 
# list is stable between julia 1.0 and 1.6
# https://github.com/JuliaLang/julia/blob/release-1.6/stdlib/Logging/src/Logging.jl#L32-L46
using Logging

export Logging, AbstractLogger, LogLevel, NullLogger,
    @debug, @info, @warn, @error, @logmsg,
    with_logger, current_logger, global_logger, disable_logging,
    SimpleLogger, ConsoleLogger


include("CompositionalLoggers/common.jl")
include("CompositionalLoggers/activefiltered.jl")
include("CompositionalLoggers/earlyfiltered.jl")
include("CompositionalLoggers/minlevelfiltered.jl")
include("CompositionalLoggers/tee.jl")
include("CompositionalLoggers/transformer.jl")
include("CompositionalLoggers/overridelogger.jl")

include("Sinks/formatlogger.jl")
include("Sinks/filelogger.jl")
include("Sinks/datetime_rotation.jl")


include("verbosity.jl")
include("deprecated.jl")

end # module
