function with(f; level::Union{Int, LogLevel}=Info, verbosity::Int=0)
    with_logger(genlogger(level, verbosity)) do
        f()
    end
end

genlogger(l, v) = ActiveFilteredLogger(
    LogVerbosityCheck(v),
    TransformerLogger(
        args -> merge(args, (kwargs=Base.structdiff(values(args.kwargs), (verbosity=0,)),)),
        LevelOverrideLogger(l, current_logger())
    )
)

struct LogVerbosityCheck
    verbosity::Int
end

function (f::LogVerbosityCheck)(logargs)
    kw = values(logargs.kwargs)
    return !haskey(kw, :verbosity) || f.verbosity >= kw.verbosity
end