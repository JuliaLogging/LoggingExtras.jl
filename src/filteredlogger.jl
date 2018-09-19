
"""
	FilteredLogger(filter, logger)
	
Wraps `logger` in a filter.
While loggers intrinsictally have in built filtering mechanisms.
Wrapping it in a FilterLogger allows for extract control,
at the cost of a bit of overhead.

The `filter` should be a function that returns a boolean.
`true` if the message should be logged and `false` if not.
It should take as inputs:
`(level, message, _module, group, id, file, line; kwargs...)`

These argument come from the logging macro (@info`, `@warn` etc).
  
  * `level::LogLevel` Warn, Info, etc,
  * `message::String` the message to be logged
  * `_module::Module` can be used to specify a different originating module from
    the source location of the message.
  * `group::Symbol` can be used to override the message group (this is
    normally derived from the base name of the source file).
  * `id::Symbol` can be used to override the automatically generated unique
    message identifier.  This is useful if you need to very closely associate
    messages generated on different source lines.
  * `file::String` and `line::Int` can be used to override the apparent
    source location of a log message.
  * `kwargs...` any keyword or positional arguments to the logging macro.
"""
struct FilteredLogger{T <: AbstractLogger, F} <: AbstractLogger
	filter::F
	logger::T
end


function handle_message(filteredlogger::FilteredLogger, level, message, _module, group, id, file, line; kwargs...)
	if filteredlogger.filter(level, message, _module, group, id, file, line; kwargs...)
		handle_message(filteredlogger.logger, level, message, _module, group, id, file, line; kwargs...)
	end
end

shouldlog(filteredlogger::FilteredLogger, level, _module, group, id) = shouldlog(filteredlogger.logger, level, _module, group, id)
min_enabled_level(filteredlogger::FilteredLogger) = min_enabled_level(filteredlogger.logger)
catch_exceptions(filteredlogger::FilteredLogger) = catch_exceptions(filteredlogger.logger)
