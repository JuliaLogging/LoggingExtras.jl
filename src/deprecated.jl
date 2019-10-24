
Base.@deprecate(
    DemuxLogger(loggers::Vararg{AbstractLogger}; include_current_global=true),
    include_current_global ? TeeLogger(global_logger(), loggers...) : TeeLogger(loggers...)
)
