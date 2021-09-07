# copied from https://github.com/JuliaLang/julia/blob/v1.5.4/stdlib/Logging/src/ConsoleLogger.jl
using Logging
import Logging: min_enabled_level, shouldlog, catch_exceptions, handle_message

function shorten_str(message, max_len)
    suffix = "…"
    if length(message) > max_len
        message[1:min(end, max_len-length(suffix))] * suffix
    else
        message
    end
end

function make_log_truncated(max_var_len=5_000)
    function log_truncated(io, args)
        levelstr = args.level == Logging.Warn ? "Warning" : string(args.level)
        msglines = split(chomp(string(shorten_str(args.message, max_var_len))), '\n')
        println(io, "┌ ", levelstr, ": ", msglines[1])
        for i in 2:length(msglines)
            str_line = sprint(print, "│ ", msglines[i])
            println(io, shorten_str(str_line, max_var_len))
        end
        for (key, val) in args.kwargs
            str_line = sprint(print, "│   ", key, " = ", val)
            println(io, shorten_str(str_line, max_var_len))
        end
        println(io, "└ @ ", something(args._module, "nothing"), " ",
                something(args.file, "nothing"), ":", something(args.line, "nothing"))
        nothing
    end
    log_truncated
end
