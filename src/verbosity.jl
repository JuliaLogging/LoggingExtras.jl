"""Calls @debug with the passed verbosity level"""
macro debugv(verbosity::Int64, msg, exs...)
    return esc(:($Base.@debug $msg verbosity=$verbosity $(exs...)))
end

"""Calls @info with the passed verbosity level"""
macro infov(verbosity::Int64, msg, exs...)
    return esc(:($Base.@info $msg verbosity=$verbosity $(exs...)))
end

"""Calls @warn with the passed verbosity level"""
macro warnv(verbosity::Int64, msg, exs...)
    return esc(:($Base.@warn $msg verbosity=$verbosity $(exs...)))
end

"""Calls @error with the passed verbosity level"""
macro errorv(verbosity::Int64, msg, exs...)
    return esc(:($Base.@error $msg verbosity=$verbosity $(exs...)))
end

"""Calls @error with the passed verbosity level"""
macro logmsgv(verbosity::Int64, level, msg, exs...)
    return esc(:($Base.@logmsgv $level $msg verbosity=$verbosity $(exs...)))
end
