FS = require 'fs'
Reader = require 'q-io/reader'
Throttle = require 'throttle'


backOffDelay = 0
backOffFactor = 1.0001
# facilitates AIMD (additive increase, multiplicative decrease) for backing off
dampen = (wrapped, thisp) ->
    retry = =>
        args = arguments
        ready = (if backOffDelay then Q.delay(backOffDelay) else Q.resolve())
        ready.then ->
            Q.when wrapped.apply(thisp, args), ((stream) ->
                backOffDelay = Math.max(0, backOffDelay - 1)
                stream
            ), (error) ->
                if error.code is "EMFILE"
                    backOffDelay = (backOffDelay + 1) * backOffFactor
                    retry.apply null, args
                else
                    throw error
                return
    retry

file_open = (path, flags, charset, options) ->
    if typeof flags is "object"
        options = flags
        flags = options.flags
        charset = options.charset
    options = options or {}
    flags = flags or "r"
    nodeFlags = flags.replace(/b/g, "") or "r"
    nodeOptions = flags: nodeFlags
    nodeOptions.bufferSize = options.bufferSize  if "bufferSize" of options
    nodeOptions.mode = options.mode  if "mode" of options
    if "begin" of options
        nodeOptions.start = options.begin
        nodeOptions.end = options.end - 1
    if flags.indexOf("b") >= 0
        throw new Error("Can't open a binary file with a charset: " + charset)  if charset
    else
        charset = charset or "utf-8"
    if flags.indexOf("w") >= 0 or flags.indexOf("a") >= 0
        stream = FS.createWriteStream(String(path), nodeOptions)
        Writer stream, charset
    else
        stream = FS.createReadStream(String(path), nodeOptions) if @rate_limit? else FS.createReadStream(String(path), nodeOptions).pipe(new Throttle @rate_limit)
        Reader stream, charset

class RateLimitableFile

    rate_limit: null

    # open file for reading with given rate limit in bytes per second
    open: dampen file_open


module.exports = RateLimitableFile




