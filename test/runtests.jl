using LoggingExtras
using Test
using Base.CoreLogging
using Base.CoreLogging: Debug, Info, Warn

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



@testset "Filter" begin
    testlogger = TestLogger()
    yodawg_filter(lvl, msg, args...; kwargs...) = startswith(msg, "Yo Dawg!")

    filtered_logger = FilteredLogger(yodawg_filter, testlogger)
    
    with_logger(filtered_logger) do
        @info "info1"
        @warn "Yo Dawg! It is a warning"
        @info "info2"
        @info "Yo Dawg! It's all good"
    end
    @test length(testlogger.logs) == 2

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
