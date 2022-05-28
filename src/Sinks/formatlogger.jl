
struct FormatLogger <: AbstractLogger
    f::Function
    stream::IO
    always_flush::Bool
end

"""
    FormatLogger(f::Function, io::IO=stderr; always_flush=true)

Logger sink that formats the message and finally writes to `io`.
The formatting function should be of the form `f(io::IOContext, log_args::NamedTuple)`
where `log_args` has the following fields:
`(level, message, _module, group, id, file, line, kwargs)`.
See [`LoggingExtras.handle_message_args`](@ref) for more information on what field is.

# Examples
```julia-repl
julia> using Logging, LoggingExtras

julia> logger = FormatLogger() do io, args
           println(io, args._module, " | ", "[", args.level, "] ", args.message)
       end;

julia> with_logger(logger) do
           @info "This is an informational message."
           @warn "This is a warning, should take a look."
       end
Main | [Info] This is an informational message.
Main | [Warn] This is a warning, should take a look.
```
"""
function FormatLogger(f::Function, io::IO=stderr; always_flush=true)
    return FormatLogger(f, io, always_flush)
end

"""
    FormatLogger(f::Function, path::AbstractString; append=false, always_flush=true)

Logger sink that formats the message and writes it to the file at `path`.  This is similar
to `FileLogger` except that it allows specifying the printing format.

To append to the file (rather than truncating the file first), use `append=true`.
If `always_flush=true` the stream is flushed after every handled log message.
"""
function FormatLogger(f::Function, path::AbstractString; append::Bool=false, kw...)
    io = open(path, append ? "a" : "w")
    return FormatLogger(f, io; kw...)
end

function handle_message(logger::FormatLogger, args...; kwargs...)
    log_args = handle_message_args(args...; kwargs...)
    # We help the user by passing an IOBuffer to the formatting function
    # to make sure that everything writes to the logger io in one go.
    iob = IOBuffer()
    ioc = IOContext(iob, logger.stream)
    logger.f(ioc, log_args)
    write(logger.stream, take!(iob))
    logger.always_flush && flush(logger.stream)
    return nothing
end
shouldlog(logger::FormatLogger, arg...) = true
min_enabled_level(logger::FormatLogger) = BelowMinLevel
catch_exceptions(logger::FormatLogger) = true # Or false? SimpleLogger doesn't, ConsoleLogger does.
