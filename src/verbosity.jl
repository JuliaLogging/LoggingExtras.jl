function restore_callsite_source_position!(expr, src)
    @assert expr.head == :escape
    @assert expr.args[1].head == :macrocall
    @assert expr.args[1].args[2] isa LineNumberNode
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
for a given log level. The verbosity argument is subtracted from the base log level when passed down
to the core logging logic, so `@debugv 1 msg` will essentially call `@logmsg Debug-1 msg`.

An `LoggingExtras.LevelOverrideLogger`can then be used to filter on the `level` argument.
For convenience, the
[`LoggintExtras.with(f; level, verbosity)`](@ref) function is provided to temporarily
wrap the current logger with a log level and verbosity subtracted to filter while `f` is executed.
"""

"$vlogmacrodocs"
macro debugv(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@logmsg (Logging.Debug - $verbosity) $msg $(exs...))),
        __source__,
    )
end

"$vlogmacrodocs"
macro infov(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@logmsg (Logging.Info - $verbosity) $msg $(exs...))),
        __source__,
    )
end

"$vlogmacrodocs"
macro warnv(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@logmsg (Logging.Warn - $verbosity) $msg $(exs...))),
        __source__,
    )
end

"$vlogmacrodocs"
macro errorv(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@logmsg (Logging.Error - $verbosity) $msg $(exs...))),
        __source__,
    )
end

"$vlogmacrodocs"
macro logmsgv(verbosity::Int, level, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@logmsg ($level - $verbosity) $msg $(exs...))),
        __source__,
    )
end

"""
    LoggingExtras.withlevel(f, level; verbosity::Integer=0)

Convenience function like `Logging.with_logger` to temporarily wrap
the current logger with a level filter while `f` is executed.
That is, the current logger will still be used for actual logging, but
log messages will first be checked that they meet the `level`
log level before being passed on to be logged.
"""
function withlevel(f, level::Union{Int, LogLevel}=Info; verbosity::Integer=0)
    lvl = Base.CoreLogging._min_enabled_level[]
    try
        # by default, this global filter is Debug, but for debug logging
        # we want to enable sub-Debug levels
        Base.CoreLogging._min_enabled_level[] = BelowMinLevel
        with_logger(LevelOverrideLogger(level - verbosity, current_logger())) do
            f()
        end
    finally
        Base.CoreLogging._min_enabled_level[] = lvl
    end
end
