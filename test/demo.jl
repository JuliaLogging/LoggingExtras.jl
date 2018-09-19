
using Logging; using LoggingExtras

yodawg_filter(lvl, msg, args...; kwargs...) = startswith(msg, "Yo Dawg!")
filtered_logger = FilteredLogger(yodawg_filter, global_logger())
with_logger(filtered_logger) do
    @info "Boring message"
    @warn "Yo Dawg! it is bad"
    @info "Another boring message"
    @info "Yo Dawg! it is all good"
end




demux_logger = DemuxLogger(
    FileLogger("info.log", min_level=Logging.Info),
    FileLogger("warn.log", min_level=Logging.Warn),
    include_current_global=false
    )
with_logger(demux_logger) do
    @warn("It is bad")
    @info("normal stuff")
    @error("THE WORSE THING")
    @debug("it is chill")
end

; cat warn.log
; cat info.log

