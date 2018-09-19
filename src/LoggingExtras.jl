module LoggingExtras

using Base.CoreLogging:
    global_logger,
    LogLevel, BelowMinLevel, Debug, Info, Warn, Error, AboveMaxLevel

import Base.CoreLogging:
    AbstractLogger, SimpleLogger,
	handle_message, shouldlog, min_enabled_level, catch_exceptions

export demux_global_logger,
    DemuxLogger, FilteredLogger, FileLogger

include("demuxlogger.jl")
include("filteredlogger.jl")
include("filelogger.jl")

end # module
