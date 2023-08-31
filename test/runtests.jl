using LoggingExtras
using Test
using Test: collect_test_logs, TestLogger
using Dates

using Base.CoreLogging
using Base.CoreLogging: BelowMinLevel, Debug, Info, Warn, Error


@testset "Tee" begin
    @testset "contructor" begin
        @testset "mixed types" begin
            @test TeeLogger(TestLogger(), NullLogger()) isa TeeLogger
        end

        @testset "errors if given nonloggers" begin
            @test_throws Exception TeeLogger(stdout, stderr)
        end
    end
    @testset "basic use with compositional levels" begin
        testlogger_info = TestLogger(min_level=Info)
        testlogger_warn = TestLogger(min_level=Warn)

        with_logger(TeeLogger(testlogger_warn, testlogger_info)) do
            @info "info1"
            @warn "warn1"
            @info "info2"
        end
        @test length(testlogger_info.logs) == 3
        @test length(testlogger_warn.logs) == 1
    end
end


@testset "File" begin
    mktempdir() do dir
        for (filepath, sink) in [
                (f = joinpath(dir, "log"); (f, f)), # Filepath
                (f = joinpath(dir, "log_io"); (f, open(f, "w"))), # IOStream
            ]
            with_logger(FileLogger(sink)) do
                @info "first"
                @warn "second"
                @info "third"
            end
            sink isa IOStream && close(sink)
            logtext = read(filepath, String)
            @test occursin("first", logtext)
            @test occursin("second", logtext)
            @test occursin("third", logtext)
        end
    end
end


@testset "Active Filter" begin
    testlogger = TestLogger()
    yodawg_filter(logargs) = startswith(logargs.message, "Yo Dawg!")

    filtered_logger = ActiveFilteredLogger(yodawg_filter, testlogger)

    with_logger(filtered_logger) do
        @info "info1"
        @warn "Yo Dawg! It is a warning"
        @info "info2"
        @info "Yo Dawg! It's all good"
        @info "info 3"
    end
    @test length(testlogger.logs) == 2
end

@testset "Early Filter" begin
    testlogger = TestLogger()
    filtered_logger = EarlyFilteredLogger(testlogger) do logargs
        logargs.level == Info  # Only exactly Info, nothing more nothing less
    end

    with_logger(filtered_logger) do
        @info "info1"
        @warn "Yo Dawg! It is a warning"
        @info "info2"
        @info "Yo Dawg! It's all good"
    end
    @test length(testlogger.logs) == 3
end

@testset "MinLevel Filter" begin
    testlogger = TestLogger()
    filtered_logger = MinLevelLogger(testlogger, Warn)

    with_logger(filtered_logger) do
        @info "info1"
        @warn "Yo Dawg! It is a warning"
        @info "info2"
        @info "Yo Dawg! It's all good"
        @info "info 3"
        @error "MISTAKES WERE MADE"
    end
    @test length(testlogger.logs) == 2
end


@testset "Transformer" begin
    testlogger = TestLogger(min_level=Error)
    transformer_logger = TransformerLogger(testlogger) do log_msg
        # We are going to transform all warnings into errors
        if log_msg.level == Warn
            return merge(log_msg, (; level=Error))
        else
            return log_msg
        end
    end

    with_logger(transformer_logger) do
        @info "info1"
        @warn "Yo Dawg! It is a warning"
        @info "info2"
        @info "Yo Dawg! It's all good"
        @info "info 3"
        @error "MISTAKES WERE MADE"
    end
    @test length(testlogger.logs) == 2
end

@testset "DatetimeRotatingFileLogger" begin
    mktempdir() do dir
        drfl_min = DatetimeRotatingFileLogger(dir, raw"\m\i\n-YYYY-mm-dd-HH-MM.\l\o\g")
        drfl_hour = DatetimeRotatingFileLogger(dir, raw"\h\o\u\r-YYYY-mm-dd-HH.\l\o\g")
        func = (io, args) -> println(io, reverse(args.message))
        drfl_fmt = DatetimeRotatingFileLogger(func, dir, raw"\f\m\t-YYYY-mm-dd-HH-MM.\l\o\g")
        callback_record = []
        callback(f) = filesize(f) > 0 && push!(callback_record, f)
        drfl_cb = DatetimeRotatingFileLogger(dir, raw"\c\o\m\p-YYYY-mm-dd-HH-MM.\l\o\g";
                                             rotation_callback=callback)

        sink = TeeLogger(drfl_min, drfl_hour, drfl_fmt, drfl_cb)
        with_logger(sink) do
            # Make sure to trigger one minute-level rotation and no hour-level
            # rotation by sleeping until HH:MM:55
            n = now()
            sleeptime = mod((55 - second(n)), 60)
            minute(n) == 59 && (sleeptime += 60)
            sleep(sleeptime)
            @info "first"
            @info "second"
            sleep(10) # Should rotate to next minute
            @info("third")
        end

        # Drop anything that's not a .log file or empty
        files = sort(map(f -> joinpath(dir, f), readdir(dir)))
        files = filter(f -> endswith(f, ".log") && filesize(f) > 0, files)
        min_files = filter(f -> startswith(basename(f), "min-"), files)
        @test length(min_files) == 2

        hour_files = filter(f -> startswith(basename(f), "hour-"), files)
        @test length(hour_files) == 1

        fmt_files = filter(f -> startswith(basename(f), "fmt-"), files)
        @test length(fmt_files) == 2

        # Two files exist, but just one have been rotated
        @test length(callback_record) == 1
        @test occursin(r"comp-\d{4}(-\d{2}){4}\.log$", callback_record[1])

        min1_data = String(read(min_files[1]))
        @test occursin("first", min1_data)
        @test occursin("second", min1_data)
        min2_data = String(read(min_files[2]))
        @test occursin("third", min2_data)

        min_data = String(read(hour_files[1]))
        @test occursin("first", min_data)
        @test occursin("second", min_data)
        @test occursin("third", min_data)

        fmt_data = String(read(fmt_files[1]))
        @test occursin("tsrif", fmt_data)
        @test occursin("dnoces", fmt_data)
        fmt_data = String(read(fmt_files[2]))
        @test occursin("driht", fmt_data)

        # Sub-minute resolution not allowed
        @test_throws(ArgumentError("rotating the logger with sub-minute resolution not supported"),
                     DatetimeRotatingFileLogger(dir, "HH-MM-SS"))

        # Test constructors with pattern as a DateFormat
        l = DatetimeRotatingFileLogger(dir, raw"yyyy-mm-dd.\l\o\g")
        l1 = DatetimeRotatingFileLogger(dir, dateformat"yyyy-mm-dd.\l\o\g")
        l2 = DatetimeRotatingFileLogger(identity, dir, dateformat"yyyy-mm-dd.\l\o\g")
        @test l.filename_pattern == l1.filename_pattern == l2.filename_pattern

        # Test large resolutions, which have some weirdness related to ordering
        # (see next_datetime_transition()). These should not throw.
        DatetimeRotatingFileLogger(dir, raw"yyyy-mm.\l\o\g")
        DatetimeRotatingFileLogger(dir, raw"yyyy.\l\o\g")
    end
end

@testset "FormatLogger" begin
    io = IOBuffer()
    logger = FormatLogger(io) do io, args
        # Put in some bogus sleep calls just to test that
        # log records writes in one go
        print(io, args.level)
        sleep(rand())
        print(io, ": ")
        sleep(rand())
        println(io, args.message)
    end
    with_logger(logger) do
        @sync begin
            @async @debug "debug message"
            @async @info "info message"
            @async @warn "warning message"
            @async @error "error message"
        end
    end
    str = String(take!(io))
    @test occursin(r"^Debug: debug message$"m, str)
    @test occursin(r"^Info: info message$"m, str)
    @test occursin(r"^Warn: warning message$"m, str)
    @test occursin(r"^Error: error message$"m, str)
    @test logger.always_flush
    # Test constructor with default io and kwarg
    logger = FormatLogger(x -> x; always_flush=false)
    @test logger.stream === stderr
    @test !logger.always_flush

    # test file arguments
    mktempdir() do dir
        f = joinpath(dir, "test.log")

        logger = FormatLogger(f) do io, args
            println(io, "log message")
        end

        with_logger(logger) do
            @info "test message"
        end

        l = read(f, String)
        @test startswith(l, "log message")
    end
end

@testset "LevelOverrideLogger" begin
    logger = TestLogger(min_level=Info)
    with_logger(LevelOverrideLogger(Debug, logger)) do
        @debug "debug message"
        @info "info message"

    end
    @test length(logger.logs) == 2
    @test map(x -> x.level, logger.logs) == [Debug, Info]
end

@testset "Verbosity utilities" begin
    logger = TestLogger(min_level=Info)
    with_logger(logger) do
        @infov 1 "info 1 message"
    end
    # if no verbosity filter is used, message is just like @info
    @test !isempty(logger.logs)

    logger = TestLogger(min_level=Info)
    with_logger(logger) do
        LoggingExtras.withlevel(Debug) do
            @debug "debug message"
        end
    end
    @test logger.logs[1].level == Debug

    logger = TestLogger(min_level=Info)
    with_logger(logger) do
        LoggingExtras.withlevel(Debug; verbosity=1) do
            @debugv 0 "debug 0 message"
            @debugv 1 "debug 1 message"
            @debugv 2 "debug 2 message"
            # error message *also* isn't logged since
            # level *and* verbosity must match
            @errorv 2 "error 2 message"
        end
    end
    @test length(logger.logs) == 2
    @test logger.logs[1].group == LoggingExtras.Verbosity(0)
    @test logger.logs[2].group == LoggingExtras.Verbosity(1)

    logger = TestLogger(min_level=Info)
    with_logger(logger) do
        with_logger(MinLevelLogger(current_logger(), Info)) do
            LoggingExtras.withlevel(Debug; verbosity=1) do
                @debug "This should show up, even though it is behind 2 info level filters"
            end
        end
    end
    @test length(logger.logs) == 1
end

# Define a module for testing conditional debug messages
module JuliaDebugTest

    function debug_message(str)
        @debug str
    end

end

@testset "JULIA_DEBUG" begin
    expected_messages = 0
    logger = TestLogger(min_level=Info)
    with_logger(logger) do
        JuliaDebugTest.debug_message("debug")
    end
    @test length(logger.logs) == expected_messages

    extra_logger = TransformerLogger(logger) do log
        merge(log, (; message="New message"))
    end
    with_logger(extra_logger) do
        JuliaDebugTest.debug_message("debug")
    end
    @test length(logger.logs) == expected_messages

    ENV["JULIA_DEBUG"] = "JuliaDebugTest"
    with_logger(logger) do
        JuliaDebugTest.debug_message("debug")
        expected_messages += 1
    end
    @test length(logger.logs) == expected_messages

    with_logger(extra_logger) do
        JuliaDebugTest.debug_message("debug")
        expected_messages += 1
    end
    @test length(logger.logs) == expected_messages

    delete!(ENV, "JULIA_DEBUG")
    with_logger(extra_logger) do
        JuliaDebugTest.debug_message("debug")
    end
    @test length(logger.logs) == expected_messages
end

@testset "Deprecations" begin
    # Nothing is currently deprecated
end
