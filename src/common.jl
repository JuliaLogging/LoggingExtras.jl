
"""
    MessageHandled(::Bool)

`MessageHandled(false)` should be returned from a `handle_message` on a logger,
if it did not actually handle the log message.
For example, if the log message was below the level it should log.
This is of particular relevance to the [`ActiveFilteredLogger`](@ref), which can't know
util `handle_message` if a log message will be filtered or not.
Ideally, `MessageHandled(true)` would be returned from loggers when when they
successfully handled a message, however this is not strictly required.
E.g Sinks should always return `MessageHandled(true)`.
"""
struct MessageHandled
    val :: Bool
end

was_handled(response) = true  # If we don;t get a MessageHandled then assume worked
was_handled(response::MessageHandled) = response.val


# Since the logging system itself will not engage its checks
# Once the first logger has started, any compositional logger needs to check
# before passing anything on.

# For checking child logger, need to check both `min_enabled_level` and `shouldlog`
function comp_shouldlog(logger, args...)
    level = first(args)
    min_enabled_level(logger) <= level && shouldlog(logger, args...)
end

# For checking if child logger will take the message you are sending
function comp_handle_message_check(logger, args...; kwargs...)
    level, message, _module, group, id, file, line = args
    return comp_shouldlog(logger, level, _module, group, id)
end
