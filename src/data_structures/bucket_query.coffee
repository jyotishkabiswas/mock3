class BucketQuery

    constructor: ->

        @prefix = null
        @matches = null
        @marker = null
        @max_keys = null
        @delimiter = null
        @bucket = null
        @is_truncated = null

module.exports = BucketQuery