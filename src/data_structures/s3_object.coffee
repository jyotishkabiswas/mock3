String.prototype.hashCode = ->
    hash = 0
    if @length is 0 then return hash

    for i in [0...@length]
        char = @charCodeAt i
        hash = ((hash<<5)-hash) + char
        hash = hash & hash

    hash

class S3Object extends Object

    constructor: ->

        @name = null
        @size = null
        @creation_date = null
        @md5 = null
        @io = null
        @content_type = null
        @custom_metadata = null
        @root = null

    hash: ->
        @name.hashCode()

module.exports = S3Object
