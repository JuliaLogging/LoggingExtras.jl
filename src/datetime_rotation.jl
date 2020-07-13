using Dates
import Base: isless

raw"""
    DatetimeRotatingFileLogger

Constructs a FileLogger that rotates its file based on the current date.
The filename pattern given is interpreted through the `Dates.format()` string formatter,
allowing for yearly all the way down to millisecond-level log rotation.  Note that if you
wish to have a filename portion that is not interpreted as a format string, you may need
to escape portions of the filename, as shown below:

Usage example:

    logger = DatetimeRotatingFileLogger(log_dir, raw"\a\c\c\e\s\s-YYYY-mm-dd.\l\o\g")
"""
mutable struct DatetimeRotatingFileLogger <: AbstractLogger
    logger::SimpleLogger
    dir::String
    filename_pattern::DateFormat
    next_reopen_check::DateTime
    always_flush::Bool
end

function DatetimeRotatingFileLogger(dir, filename_pattern; always_flush=true)
    format = DateFormat(filename_pattern)
    return DatetimeRotatingFileLogger(
        SimpleLogger(open(calc_logpath(dir, filename_pattern), "a"), BelowMinLevel),
        dir,
        format,
        next_datetime_transition(format),
        always_flush,
    )
end

function reopen!(drfl::DatetimeRotatingFileLogger)
    drfl.logger = SimpleLogger(open(calc_logpath(drfl.dir, drfl.filename_pattern), "a"), BelowMinLevel)
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
