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

# I kind of wish these were defined in Dates
isless(::Type{Millisecond}, ::Type{Millisecond}) = false
isless(::Type{Millisecond}, ::Type{T}) where {T <: Dates.Period} = true

isless(::Type{Second}, ::Type{Millisecond}) = false
isless(::Type{Second}, ::Type{Second}) = false
isless(::Type{Second}, ::Type{T}) where {T <: Dates.Period} = true

isless(::Type{Minute}, ::Type{Millisecond}) = false
isless(::Type{Minute}, ::Type{Second}) = false
isless(::Type{Minute}, ::Type{Minute}) = false
isless(::Type{Minute}, ::Type{T}) where {T <: Dates.Period} = true

isless(::Type{Hour}, ::Type{Day}) = true
isless(::Type{Hour}, ::Type{Month}) = true
isless(::Type{Hour}, ::Type{Year}) = true
isless(::Type{Hour}, ::Type{T}) where {T <: Dates.Period} = false

isless(::Type{Day}, ::Type{Month}) = true
isless(::Type{Day}, ::Type{Year}) = true
isless(::Type{Day}, ::Type{T}) where {T <: Dates.Period} = false

isless(::Type{Month}, ::Type{Year}) = true
isless(::Type{Month}, ::Type{T}) where {T <: Dates.Period} = false

isless(::Type{Year}, ::Type{T}) where {T <: Dates.Period} = false

"""
    next_datetime_transition(fmt::DateFormat)

Given a DateFormat that is being applied to our filename, what is the next
time at which our filepath will need to change?
"""
function next_datetime_transition(fmt::DateFormat)
    extract_token(x::Dates.DatePart{T}) where {T} = T
    token_timescales = Dict(
        # Milliseconds is the smallest timescale
        's' => Millisecond,
        # Seconds
        'S' => Second,
        # Minutes
        'M' => Minute,
        # Hours
        'I' => Hour,
        'H' => Hour,
        # Days
        'd' => Day,
        'e' => Day,
        'E' => Day,
        # Month
        'm' => Month,
        'u' => Month,
        'U' => Month,
        # Year
        'y' => Year,
        'Y' => Year,
    )

    tokens = filter(t -> isa(t, Dates.DatePart), collect(fmt.tokens))
    minimum_timescale = minimum(map(t -> token_timescales[extract_token(t)], tokens))
    return Dates.ceil(now(), minimum_timescale) - Second(1)
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
