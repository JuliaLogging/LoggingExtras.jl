
struct FormatLogger <: AbstractLogger
    f::Function
    io::IO
    always_flush::Bool
end

"""
    FormatLogger(f::Function, io::IO=stderr; always_flush=true)

Logger sink that formats the message and finally writes to `io`.
The formatting function should be of the form `f(io::IOContext, log_args::NamedTuple)`
where `log_args` has the following fields:
`(level, message, _module, group, id, file, line, kwargs)`.
See `?LoggingExtra.handle_message_args` for more information on what field is.

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

function handle_message(logger::FormatLogger, args...; kwargs...)
    log_args = handle_message_args(args...; kwargs...)
    # We help the user by passing an IOBuffer to the formatting function
    # to make sure that everything writes to the logger io in one go.
    iob = IOBuffer()
    ioc = IOContext(iob, logger.io)
    logger.f(ioc, log_args)
    write(logger.io, take!(iob))
    logger.always_flush && flush(logger.io)
    return nothing
end
shouldlog(logger::FormatLogger, arg...) = true
min_enabled_level(logger::FormatLogger) = BelowMinLevel
catch_exceptions(logger::FormatLogger) = true # Or false? SimpleLogger doesn't, ConsoleLogger does.
