using Dates

@doc raw"""
    DatetimeRotatingFileLogger(dir, file_pattern; always_flush=true, rotation_callback=identity)
    DatetimeRotatingFileLogger(f::Function, dir, file_pattern; always_flush=true, rotation_callback=identity)

Construct a `DatetimeRotatingFileLogger` that rotates its file based on the current date.
The constructor takes a log output directory, `dir`, and a filename pattern. The smallest
time resolution in the format string determines the frequency of log file rotation,
allowing for yearly all the way down to minute-level log rotation.

The pattern can be given as a string or as a `Dates.DateFormat`. Note that if you
wish to have a filename portion that should not be interpreted as a format string, you may
need to escape portions of the filename, as shown in the example below.

It is possible to pass a formatter function as the first argument to control the output.
The formatting function should be of the form `f(io::IOContext, log_args::NamedTuple)`
where `log_args` has the following fields:
`(level, message, _module, group, id, file, line, kwargs)`.
See [`LoggingExtras.handle_message_args`](@ref) for more information about what each field represents.

It is also possible to pass `rotation_callback::Function` as a keyword argument. This function
will be called every time a file rotation is happening. The function should accept one
argument which is the absolute path to the just-rotated file. The logger will block until
the callback function returns. Use `@async` if the callback is expensive.

# Examples

```julia
# Logger that logs to a new file every day
logger = DatetimeRotatingFileLogger(log_dir, raw"\a\c\c\e\s\s-yyyy-mm-dd.\l\o\g")

# Logger with a formatter function that rotates the log file hourly
logger = DatetimeRotatingFileLogger(log_dir, raw"yyyy-mm-dd-HH.\l\o\g") do io, args
    println(io, args.level, " | ", args.message)
end

# Example callback function to compress the recently-closed file
compressor(file) = run(`gzip $(file)`)
logger = DatetimeRotatingFileLogger(...; rotation_callback=compressor)
```
"""
mutable struct DatetimeRotatingFileLogger <: AbstractLogger
    logger::Union{SimpleLogger,FormatLogger}
    dir::String
    filename_pattern::DateFormat
    next_reopen_check::DateTime
    always_flush::Bool
    reopen_lock::ReentrantLock
    current_file::Union{String,Nothing}
    rotation_callback::Function
end

function DatetimeRotatingFileLogger(dir, filename_pattern; always_flush=true, rotation_callback=identity)
    DatetimeRotatingFileLogger(nothing, dir, filename_pattern; always_flush=always_flush, rotation_callback=rotation_callback)
end
function DatetimeRotatingFileLogger(f::Union{Function,Nothing}, dir, filename_pattern; always_flush=true, rotation_callback=identity)
    # Construct the backing logger with a temp IOBuffer that will be replaced
    # by the correct filestream in the call to reopen! below
    logger = if f === nothing
        SimpleLogger(IOBuffer(), BelowMinLevel)
    else # f isa Function
        FormatLogger(f, IOBuffer(); always_flush=false) # no need to flush twice
    end
    filename_pattern isa DateFormat || (filename_pattern = DateFormat(filename_pattern))
    # abspath in case user constructs the logger with a relative path and later cd's.
    drfl = DatetimeRotatingFileLogger(logger, abspath(dir),
        filename_pattern, now(), always_flush, ReentrantLock(), nothing, rotation_callback)
    reopen!(drfl)
    return drfl
end

similar_logger(::SimpleLogger, io) = SimpleLogger(io, BelowMinLevel)
similar_logger(l::FormatLogger, io) = FormatLogger(l.f, io, l.always_flush)
function reopen!(drfl::DatetimeRotatingFileLogger)
    if drfl.current_file !== nothing
        # close the old IOStream and pass the file to the callback
        close(drfl.logger.stream)
        drfl.rotation_callback(drfl.current_file)
    end
    new_file = calc_logpath(drfl.dir, drfl.filename_pattern)
    drfl.current_file = new_file
    io = open(new_file, "a")
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
    if custom_isless(minimum_timescale, Minute(1))
        throw(ArgumentError("rotating the logger with sub-minute resolution not supported"))
    end
    return ceil(now(), minimum_timescale)
end

calc_logpath(dir, filename_pattern) = joinpath(dir, Dates.format(now(), filename_pattern))

function handle_message(drfl::DatetimeRotatingFileLogger, args...; kwargs...)
    lock(drfl.reopen_lock) do
        if now() >= drfl.next_reopen_check
            reopen!(drfl)
        end
    end
    handle_message(drfl.logger, args...; kwargs...)
    drfl.always_flush && flush(drfl.logger.stream)
end

shouldlog(drfl::DatetimeRotatingFileLogger, arg...) = true
min_enabled_level(drfl::DatetimeRotatingFileLogger) = BelowMinLevel
catch_exceptions(drfl::DatetimeRotatingFileLogger) = catch_exceptions(drfl.logger)
