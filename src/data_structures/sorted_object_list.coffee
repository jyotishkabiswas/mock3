SortedSet = require "collections/sorted-set"

s3equals = (a, b) ->
    a.name == b.name

s3compare = (a, b) ->
    if a.name < b.name
        return -1
    if a.name > b.name
        return 1
    0

class S3MatchSet

    constructor: ->

        @matches = []
        @is_truncated = false

class SortedObjectList

    constructor: ->
        @sorted_set = SortedSet([], s3equals, s3compare)
        @object_map = {}

    count: ->
        @sorted_set.length

    find: (object_name) ->
        @object_map[object_name]

    add: (s3_object) ->
        unless s3_object?
            return

        @object_map[s3_object.name] = s3_object
        @sorted_set.push s3_object

    remove: (s3_object) ->
        unless s3_object?
            return

        delete @object_map[s3_object.name]
        @sorted_set.delete s3_object

    list: (options) ->
        marker = options.marker
        prefix = options.prefix
        max_keys = options.max_keys || 1000
        delimiter = options.delimiter

        ms = new S3MatchSet()

        marker_found = true
        pseudo = null

        if marker?
            marker_found = false
            unless @object_map[marker]?
                pseudo = new S3Object()
                psuedo.name = marker
                @sorted_set.push pseudo

        count = 0
        for s3_object in @sorted_set
            if marker_found and (not prefix or s3_object.name.indexOf(prefix) == 0)
                ++count
                if count <= max_keys
                    ms.matches.push s3_object
                else
                    is_truncated = true
                    break

            if marker? and marker is s3_object.name
                marker_found = true

        if pseudo?
            @sorted_set.delete psuedo

        ms

module.exports = SortedObjectList
