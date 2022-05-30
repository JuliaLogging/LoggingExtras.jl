struct FileLogger <: AbstractLogger
    logger::SimpleLogger
    always_flush::Bool
end

"""
    FileLogger(path::AbstractString; append=false, always_flush=true)

Create a logger sink that write messages to a file specified with `path`.
To append to the file (rather than truncating the file first), use `append=true`.
If `always_flush=true` the stream is flushed after every handled log message.

!!! note
    `FileLogger` uses the same output formatting as `SimpleLogger`. Use a `FormatLogger`
    instead of a `FileLogger` to control the output formatting.

"""
function FileLogger(path; append=false, kwargs...)
    filehandle = open(path, append ? "a" : "w")
    FileLogger(filehandle; kwargs...)
end

"""
    FileLogger(io::IOStream; always_flush=true)

Create a logger sink that write messages to the `io::IOStream`. The stream
is expected to be open and writeable.
If `always_flush=true` the stream is flushed after every handled log message.

!!! note
    `FileLogger` uses the same output formatting as `SimpleLogger`. Use a `FormatLogger`
    instead of a `FileLogger` to control the output formatting.


# Examples
```julia
io = open("path/to/file.log", "a") # append to the file
logger = FileLogger(io)
```
"""
function FileLogger(filehandle::IOStream; always_flush=true)
    FileLogger(SimpleLogger(filehandle, BelowMinLevel), always_flush)
end

function handle_message(filelogger::FileLogger, args...; kwargs...)
    handle_message(filelogger.logger, args...; kwargs...)
    filelogger.always_flush && flush(filelogger.logger.stream)
end
shouldlog(filelogger::FileLogger, arg...) = true
min_enabled_level(filelogger::FileLogger) = BelowMinLevel
catch_exceptions(filelogger::FileLogger) = catch_exceptions(filelogger.logger)
