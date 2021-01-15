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
        drfl_sec = DatetimeRotatingFileLogger(dir, raw"\s\e\c-YYYY-mm-dd-HH-MM-SS.\l\o\g")
        drfl_min = DatetimeRotatingFileLogger(dir, raw"\m\i\n-YYYY-mm-dd-HH-MM.\l\o\g")
        sink = TeeLogger(drfl_sec, drfl_min)
        with_logger(sink) do
            while millisecond(now()) < 100 || millisecond(now()) > 200
                sleep(0.001)
            end
            @info "first"
            @info "second"
            sleep(0.9)
            @info("third")
        end

        # Drop anything that's not a .log file or empty
        files = sort(map(f -> joinpath(dir, f), readdir(dir)))
        files = filter(f -> endswith(f, ".log") && filesize(f) > 0, files)
        sec_files = filter(f -> startswith(basename(f), "sec-"), files)
        @test length(sec_files) == 2

        min_files = filter(f -> startswith(basename(f), "min-"), files)
        @test length(min_files) == 1

        sec1_data = String(read(sec_files[1]))
        @test occursin("first", sec1_data)
        @test occursin("second", sec1_data)
        sec2_data = String(read(sec_files[2]))
        @test occursin("third", sec2_data)

        min_data = String(read(min_files[1]))
        @test occursin("first", min_data)
        @test occursin("second", min_data)
        @test occursin("third", min_data)
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
    @test logger.io === stderr
    @test !logger.always_flush
end

@testset "Deprecations" begin
    testlogger = TestLogger(min_level=BelowMinLevel)

    @test_logs (:warn, r"deprecated") match_mode=:any begin
        demux_logger = DemuxLogger(testlogger)
        @test demux_logger isa TeeLogger
        @test Set(demux_logger.loggers) == Set([testlogger, global_logger()])
    end

    @test_logs (:warn, r"deprecated") match_mode=:any begin
        demux_logger = DemuxLogger(testlogger; include_current_global=true)
        @test demux_logger isa TeeLogger
        @test Set(demux_logger.loggers) == Set([testlogger, global_logger()])
    end

    @test_logs (:warn, r"deprecated") match_mode=:any begin
        demux_logger = DemuxLogger(testlogger; include_current_global=false)
        @test demux_logger isa TeeLogger
        @test Set(demux_logger.loggers) == Set([testlogger])
    end
end
