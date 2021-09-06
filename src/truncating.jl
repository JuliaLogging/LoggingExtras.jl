# copied from https://github.com/JuliaLang/julia/blob/v1.5.4/stdlib/Logging/src/ConsoleLogger.jl
using Logging
import Logging: min_enabled_level, shouldlog, catch_exceptions, handle_message
# todo: maybe try to push it to generic julia logging package
struct TruncatingSimpleLogger <: AbstractLogger
    stream::IO
    min_level::LogLevel
    message_limits::Dict{Any,Int}
    max_var_len::Int
end
TruncatingSimpleLogger(stream::IO=stderr, level=Info, max_var_len=5_000) =
    TruncatingSimpleLogger(stream, level, Dict{Any,Int}(), max_var_len)

shouldlog(logger::TruncatingSimpleLogger, level, _module, group, id) =
    get(logger.message_limits, id, 1) > 0

min_enabled_level(logger::TruncatingSimpleLogger) = logger.min_level

catch_exceptions(logger::TruncatingSimpleLogger) = false

function shorten_str(message, max_len)
    suffix = "…"
    if length(message) > max_len
        message[1:min(end, max_len-length(suffix))] * suffix
    else
        message
    end
end

function handle_message(logger::TruncatingSimpleLogger, level, message, _module, group, id,
                        filepath, line; maxlog=nothing, kwargs...)
    if maxlog !== nothing && maxlog isa Integer
        remaining = get!(logger.message_limits, id, maxlog)
        logger.message_limits[id] = remaining - 1
        remaining > 0 || return
    end
    buf = IOBuffer()
    iob = IOContext(buf, logger.stream)
    levelstr = level == Logging.Warn ? "Warning" : string(level)
    msglines = split(chomp(string(shorten_str(message, logger.max_var_len))), '\n')
    println(iob, "┌ ", levelstr, ": ", msglines[1])
    for i in 2:length(msglines)
        str_line = sprint(print, "│ ", msglines[i])
        println(iob, shorten_str(str_line, logger.max_var_len))
    end
    for (key, val) in kwargs
        str_line = sprint(print, "│   ", key, " = ", val)
        println(iob, shorten_str(str_line, logger.max_var_len))
    end
    println(iob, "└ @ ", something(_module, "nothing"), " ",
            something(filepath, "nothing"), ":", something(line, "nothing"))
    write(logger.stream, take!(buf))
    nothing
end
