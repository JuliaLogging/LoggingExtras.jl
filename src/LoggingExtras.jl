module LoggingExtras

using Base.CoreLogging:
    LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel,

import Base.CoreLogging:
    AbstractLogger, SimpleLogger,
	handle_message, shouldlog, min_enabled_level, catch_exceptions,


include("demuxlogger.jl")
include("filteredlogger.jl")
include("filelogger.jl")

end # module
