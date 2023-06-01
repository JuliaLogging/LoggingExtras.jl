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
for a given log level. The verbosity argument is passed as the `group` argument
to the core logging logic as a `LoggingExtras.Verbosity` object.

Note these "verbose" logging messages will only be filtered if a filter logger is used.
A `LoggingExtras.EarlyFilteredLogger`can be used to filter on the `group.verbosity` argument.
For convenience, the
[`LoggingExtras.withlevel(f, level; verbosity)`](@ref) function is provided to temporarily
wrap the current logger with a log level and verbosity to filter while `f` is executed.
"""

struct Verbosity
    verbosity::Int
end

"$vlogmacrodocs"
macro debugv(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@debug $msg _group=$(Verbosity(verbosity)) $(exs...))),
        __source__,
    )
end

"$vlogmacrodocs"
macro infov(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@info $msg _group=$(Verbosity(verbosity)) $(exs...))),
        __source__,
    )
end

"$vlogmacrodocs"
macro warnv(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@warn $msg _group=$(Verbosity(verbosity)) $(exs...))),
        __source__,
    )
end

"$vlogmacrodocs"
macro errorv(verbosity::Int, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@error $msg _group=$(Verbosity(verbosity)) $(exs...))),
        __source__,
    )
end

"$vlogmacrodocs"
macro logmsgv(verbosity::Int, level, msg, exs...)
    return restore_callsite_source_position!(
        esc(:($Base.@logmsg $level $msg _group=$(Verbosity(verbosity)) $(exs...))),
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

For convenience, a `verbosity` keyword argument can be passed which also
filters the "verbose logging" messages; see [`@debugv`](@ref), [`@infov`](@ref),
[`@warnv`](@ref), [`@errorv`](@ref), and [`@logmsgv`](@ref).

!!! note

    If you are not using any of the LoggingExtras compositional loggers then the level 
    override just applies to the current logger. If on the other hand you are using 
    compositional loggers then the override is applied throughout the current logging tree.
    This is generally what you want, but do be aware that in the case of the 
    [`TeeLogger`](@ref) all branches of the T are overriden.
    For more control directly construct the logger you want by making use of
    [`LevelOverrideLogger`](@ref) and then use `with_logger` to make it active.
"""
function withlevel(f, level::Union{Int, LogLevel}=Info; verbosity::Integer=0)
    with_logger(EarlyFilteredLogger(
        args -> !(args.group isa Verbosity) || verbosity >= args.group.verbosity,
        propagate_level_override(level, current_logger()))
    ) do
        f()
    end
end
