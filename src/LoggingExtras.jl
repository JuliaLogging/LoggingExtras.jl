module LoggingExtras

using Base.CoreLogging:
    global_logger,
    LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel

import Base.CoreLogging:
    AbstractLogger, SimpleLogger,
    handle_message, shouldlog, min_enabled_level, catch_exceptions

export TeeLogger, TransformerLogger, FileLogger,
    ActiveFilteredLogger, EarlyFilteredLogger, MinLevelLogger


include("common.jl")

include("tee.jl")
include("transformer.jl")
include("activefiltered.jl")
include("earlyfiltered.jl")
include("minlevelfiltered.jl")
include("filelogger.jl")
include("deprecated.jl")

end # module
