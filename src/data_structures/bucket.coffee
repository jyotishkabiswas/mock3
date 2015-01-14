SortedObjectList = require './sorted_object_list'
BucketQuery = require './bucket_query'

class Bucket

    constructor: (@name, @creation_date, objects) ->
        @objects = new SortedObjectList()
        objects.forEach (obj) =>
            @objects.add objects

    find: (object_name) ->
        @objects.find object_name

    add: (object) ->
        @objects.add object

    remove: (object) ->
        @objects.remove object

    query_for_range: (options) ->
        marker = options.marker
        prefix = options.prefix
        max_keys = options.max_keys || 1000
        delimiter = options.delimiter

        match_set = @objects.list options

        bq = new BucketQuery()
        bq.bucket = @
        bq.marker = marker
        bq.prefix = prefix
        bq.max_keys = max_keys
        bq.delimiter = delimiter
        bq.matches = match_set.matches
        bq.is_truncated = match_set.is_truncated
        bq

Module.exports = Bucket