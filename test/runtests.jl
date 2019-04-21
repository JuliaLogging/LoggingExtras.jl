using LoggingExtras
using Test
using Base.CoreLogging
using Base.CoreLogging: Debug, Info, Warn, Error

using Test: collect_test_logs, TestLogger


@testset "Demux" begin
    testlogger_info = TestLogger(min_level=Info)
    testlogger_warn = TestLogger(min_level=Warn)

    with_logger(DemuxLogger(testlogger_warn, testlogger_info)) do
        @info "info1"
        @warn "warn1"
        @info "info2"
    end
    @test length(testlogger_info.logs) == 3
    @test length(testlogger_warn.logs) == 1
end


@testset "File" begin
    mktempdir() do dir
        filepath = joinpath(dir, "log")
        with_logger(FileLogger(filepath)) do
            @info "first"
            @warn "second"
            @info "third"
        end
        logtext = String(read(filepath))
        @test occursin("first", logtext)
        @test occursin("second", logtext)
        @test occursin("third", logtext)
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
