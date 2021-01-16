using Dates
import Base: isless

raw"""
    DatetimeRotatingFileLogger(dir, file_pattern; always_flush=true)
    DatetimeRotatingFileLogger(f::Function, dir, file_pattern; always_flush=true)

Construct a `DatetimeRotatingFileLogger` that rotates its file based on the current date.
The constructor takes a log output directory, `dir`, and a filename pattern.
The filename pattern given is interpreted through the `Dates.format()` string formatter,
allowing for yearly all the way down to millisecond-level log rotation.  Note that if you
wish to have a filename portion that is not interpreted as a format string, you may need
to escape portions of the filename, as shown in the example below.

It is possible to pass a formatter function as the first argument to control the output.
The formatting function should be of the form `f(io::IOContext, log_args::NamedTuple)`
where `log_args` has the following fields:
`(level, message, _module, group, id, file, line, kwargs)`.
See `?LoggingExtra.handle_message_args` for more information about what each field represents.

# Examples

```julia
# Logger that logs to a new file every day
logger = DatetimeRotatingFileLogger(log_dir, raw"\a\c\c\e\s\s-yyyy-mm-dd.\l\o\g")

# Logger with a formatter function that rotates the log file hourly
logger = DatetimeRotatingFileLogger(log_dir, raw"yyyy-mm-dd-HH.\l\o\g") do io, args
    println(io, args.level, " | ", args.message)
end
"""
mutable struct DatetimeRotatingFileLogger <: AbstractLogger
    logger::Union{SimpleLogger,FormatLogger}
    dir::String
    filename_pattern::DateFormat
    next_reopen_check::DateTime
    always_flush::Bool
end

function DatetimeRotatingFileLogger(dir, filename_pattern; always_flush=true)
    DatetimeRotatingFileLogger(nothing, dir, filename_pattern; always_flush=always_flush)
end
function DatetimeRotatingFileLogger(f::Union{Function,Nothing}, dir, filename_pattern; always_flush=true)
    # Construct the backing logger with a temp IOBuffer that will be replaced
    # by the correct filestream in the call to reopen! below
    logger = if f === nothing
        SimpleLogger(IOBuffer(), BelowMinLevel)
    else # f isa Function
        FormatLogger(f, IOBuffer(); always_flush=false) # no need to flush twice
    end
    # abspath in case user constructs the logger with a relative path and later cd's.
    drfl = DatetimeRotatingFileLogger(logger, abspath(dir),
        DateFormat(filename_pattern), now(), always_flush)
    reopen!(drfl)
    return drfl
end

similar_logger(::SimpleLogger, io) = SimpleLogger(io, BelowMinLevel)
similar_logger(l::FormatLogger, io) = FormatLogger(l.f, io, l.always_flush)
function reopen!(drfl::DatetimeRotatingFileLogger)
    io = open(calc_logpath(drfl.dir, drfl.filename_pattern), "a")
    drfl.logger = similar_logger(drfl.logger, io)
    drfl.next_reopen_check = next_datetime_transition(drfl.filename_pattern)
    return nothing
end

"""
    next_datetime_transition(fmt::DateFormat)

Given a DateFormat that is being applied to our filename, what is the next
time at which our filepath will need to change?
"""
function next_datetime_transition(fmt::DateFormat)
    extract_token(x::Dates.DatePart{T}) where {T} = T
    token_timescales = Dict(
        # Milliseconds is the smallest timescale
        's' => Millisecond(1),
        # Seconds
        'S' => Second(1),
        # Minutes
        'M' => Minute(1),
        # Hours
        'I' => Hour(1),
        'H' => Hour(1),
        # Days
        'd' => Day(1),
        'e' => Day(1),
        'E' => Day(1),
        # Month
        'm' => Month(1),
        'u' => Month(1),
        'U' => Month(1),
        # Year
        'y' => Year(1),
        'Y' => Year(1),
    )

    # Dates for some reason explicitly does not define equality between the smaller
    # timescales (Second, Minute, Day, etc..) and the larger, non-constant timescales
    # (Month, Year).  We do so explicitly here, without committing type piracy:
    custom_isless(x, y) = isless(x, y)
    custom_isless(x::Union{Millisecond,Second,Minute,Hour,Day}, y::Union{Month, Year}) = true
    custom_isless(x::Union{Month, Year}, y::Union{Millisecond,Second,Minute,Hour,Day}) = false

    tokens = filter(t -> isa(t, Dates.DatePart), collect(fmt.tokens))
    minimum_timescale = first(sort(map(t -> token_timescales[extract_token(t)], tokens), lt=custom_isless))
    return ceil(now(), minimum_timescale) - Second(1)
end

calc_logpath(dir, filename_pattern) = joinpath(dir, Dates.format(now(), filename_pattern))

function handle_message(drfl::DatetimeRotatingFileLogger, args...; kwargs...)
    if now() >= drfl.next_reopen_check
        flush(drfl.logger.stream)
        reopen!(drfl)
    end
    handle_message(drfl.logger, args...; kwargs...)
    drfl.always_flush && flush(drfl.logger.stream)
end

shouldlog(drfl::DatetimeRotatingFileLogger, arg...) = true
min_enabled_level(drfl::DatetimeRotatingFileLogger) = BelowMinLevel
catch_exceptions(drfl::DatetimeRotatingFileLogger) = catch_exceptions(drfl.logger)
