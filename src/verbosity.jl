function restore_callsite_source_position!(expr, src)
    # used to fix the logging source file + line
    # since we're lowering our verbose logging macros to the
    # Logging.jl macros; otherwise, they would always report this (verbosity.jl)
    # file as the logging callsite
    expr.args[1].args[2] = src
    return expr
end

vlogmacrodocs = """
    @debugv N msg args...
    @infov N msg args...
    @warnv N msg args...
    @errorv N msg args...

"Verbose" logging macros. Drop in replacements of standard logging macros, but an
additional verbosity level `N` is passed to indicate differing verbosity levels
for a given log level. The verbosity argument is passed as the `group` argument
to the core logging logic, so care should be taken if other loggers are being used
that also use the group argument.
Note: by default group is passed as the source file, however it is poor practice to rely on this in the first place.
Instead use the file argument for that.

An `LoggingExtras.EarlyFilteredLogger`can then be used to filter on the `group` argument.
For convenience, the
[`LoggintExtras.with(f; level, verbosity)`](@ref) function is provided to temporarily
wrap the current logger with a level/verbosity filter while `f` is executed.
"""

macro debugv(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@debug $msg _group=$verbosity $(exs...))),
        __source__,
    )
end

macro infov(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@info $msg _group=$verbosity $(exs...))),
        __source__,
    )
end

macro warnv(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@warn $msg _group=$verbosity $(exs...))),
        __source__,
    )
end

macro errorv(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@error $msg _group=$verbosity $(exs...))),
        __source__,
    )
end

macro logmsgv(verbosity::Int, level, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@logmsg $level $msg _group=$verbosity $(exs...))),
        __source__,
    )
end

@eval @doc $vlogmacrodocs :(@logmsgv)
@eval @doc $vlogmacrodocs :(@debugv)
@eval @doc $vlogmacrodocs :(@infov)
@eval @doc $vlogmacrodocs :(@warnv)
@eval @doc $vlogmacrodocs :(@errorv)

"""
    LoggingExtras.with(f; level=Info, verbosity=0)

Convenience function like `Logging.with_logger` to temporarily wrap
the current logger with a level/verbosity filter while `f` is executed.
That is, the current logger will still be used for actual logging, but
log messages will first be checked that they meet the `level` and
`verbosity` levels before being passed on to be logged.
"""
function with(f; level::Union{Int, LogLevel}=Info, verbosity::Int=0)
    with_logger(EarlyFilteredLogger(
        args -> !(args.group isa Int) || verbosity >= args.group,
        LevelOverrideLogger(level, current_logger()))
    ) do
        f()
    end
end
