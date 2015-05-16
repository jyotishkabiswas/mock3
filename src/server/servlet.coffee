FS = require 'q-io/fs'
crypto = require 'crypto'
URL = require 'url'
DOM = require('xmldom').DOMParser
Request = require './request'
XMLAdapter = require './xml_adapter'


class Servlet

    constructor: (@store, @hostname, @port) ->
        @root_hostnames = [hostname,'localhost','s3.amazonaws.com','s3.localhost']

    do_GET: (req, res) ->
        if req.get('origin')? then res.set 'Access-Control-Allow-Origin', '*'

        s_req = @_normalize_request req

        s_req.inspect()

        switch s_req.type
            when 'LIST_BUCKETS'
                res.set 'Content-Type', 'application/xml'
                buckets = @store.buckets
                res.status 200
                res.send XMLAdapter.buckets buckets
            when 'LS_BUCKET'
                bucket_obj = @store.get_bucket s_req.bucket
                if bucket_obj?
                    res.set 'Content-Type', 'application/xml'
                    res.status 200
                    if s_req.query.marker?
                        marker = s_req.query.marker.toString()
                    if s_req.query.prefix?
                        prefix = s_req.query.prefix.toString()
                    if s_req.query["max_keys"]?
                        max_keys = s_req.query["max_keys"].toString()
                    if s_req.query.delimiter?
                        delimiter = s_req.query.delimiter.toString()

                    query =
                        marker: marker || null
                        prefix: prefix || null
                        max_keys: max_keys || null
                        delimiter: delimiter || null
                    bq = bucket_obj.query_for_range query
                    res.send XMLAdapter.bucket_query(bq)
                else
                    res.set 'Content-Type', 'application/xml'
                    res.status 404
                    res.send XMLAdapter.error_no_such_bucket(s_req.bucket)
            when 'GET_ACL'
                res.set 'Content-Type', 'application/xml'
                res.status 200
                res.send XMLAdapter.acl()
            when 'GET'
                real_obj = null
                @store.get_object(s_req.bucket, s_req.object, req).then (real_obj) ->
                    res.set 'Content-Type', real_obj.content_type
                    FS.stat(FS.join(@store.root, s_req.bucket, s_req.object, FileStore.SHUCK_METADATA_DIR, 'content'))
                .then (stats) ->
                    res.set 'Last-Modified', Date.parse(real_obj.modified_date).toUTCString()
                    res.set 'ETag', "\"#{real_obj.md5}\""
                    res.set 'Accept-Ranges', 'bytes'
                    res.set 'Last-Ranges', 'bytes'
                    for k, v of real_obj.custom_metadata
                        res.set "x-amz-meta-#{k}", v
                    content_length = stats.size
                    if req.get("range")?[0]
                        res.status 206
                        range = req.get("range")[0].match /bytes=(\d*)-(\d*)/
                        if range?.length > 0
                            start = parseInt range[1]
                            finish = parseInt range[2]
                            finish_str = ""
                            if finish is 0
                                finish = content_length - 1
                                finish_str = "#{finish}"
                            else
                                finish_str = finish.toString()
                        res.set 'Content-Range', "bytes #{start}-#{finish_str}/#{content_length}"
                        real_obj.io.read().then (data) ->
                            res.send data
                            return
                    res.set 'Content-Length', content_length
                    res.status 200
                    if s_req.http_verb is 'HEAD'
                        res.end()
                    else
                        real_obj.io.read().then (data) ->
                            res.send data
                .catch (err) ->
                    res.set 'Content-Type', 'application/xml'
                    res.status 404
                    res.send XMLAdapter.error_no_such_key(s_req.object)
                    return

    do_PUT: (req, res) ->

        s_req = @_normalize_request req
        query = req.query

        if query.uploadId? then return @do_multipartPUT(req, res)

        res.set 'Content-Type', "text/xml"
        res.set 'Access-Control-Allow-Origin', '*'

        s_req.inspect()

        switch s_req.type
            when s_req.constructor.COPY
                @store.copy_object(s_req.src_bucket, s_req.src_object, s_req.bucket, s_req.object, req).then (object) ->
                    res.send XMLAdapter.copy_object_result(object)
            when s_req.constructor.STORE
                bucket_obj = @store.get_bucket(s_req.bucket)
                unless bucket_obj?
                    # TODO fix this to return the proper error
                    @store.create_bucket(s_req.bucket).then (obj) ->
                        bucket_obj = obj
                        @store.store_object(bucket_obj, s_req.object, s_req.request)
                    .then (real_obj) ->
                        res.set 'ETag', "\"#{real_obj.md5}\""
                        res.status 200
                        res.end()
                else
                    @store.store_object(bucket_obj, s_req.object, s_req.request).then (real_obj) ->
                        res.set 'ETag', "\"#{real_obj.md5}\""
                        res.status 200
                        res.end()
            when s_req.constructor.CREATE_BUCKET
                @store.create_bucket(s_req.bucket).then (bucket) ->
                    resp = XMLAdapter.bucket bucket
                    res.send resp
                    res.end()

    _do_multipartPUT: (req, res) ->
        s_req = @_normalize_request req
        query = req.query
        part_number = query.partNumber[0]
        upload_id = query.uploadId[0]
        part_name = "#{upload_id}_#{s_req.object}_part#{part_number}"
        res.set 'Access-Control-Allow-Origin', '*'
        res.set 'Access-Control-Allow-Headers', 'Authorization, Content-Length, Content-Type'
        res.set 'Access-Control-Expose-Headers', 'ETag'
        if s_req.type is s_req.constructor.COPY
            @store.copy_object(s_req.src_bucket, s_req.src_object, s_req.bucket, part_name, req).then (real_obj) ->
                res.set 'Content-Type', 'text/xml'
                res.status 200
                res.send XMLAdapter.copy_object_result(real_obj)
        else
            bucket_obj = @store.get_bucket s_req.bucket
            store.store_object(bucket_obj, part_name, req).then (real_obj) ->
                res.set 'ETag', "\"#{real_obj.md5}\""
                res.status 200
                res.end()

    do_POST: (req, res) ->
        s_req = @_normalize_request req
        query = req.query
        key = query.key

        res.set 'Content-Type', 'text/xml'
        res.set 'Access-Control-Allow-Origin', '*'
        res.set 'Access-Control-Allow-Headers', 'Authorization, Content-Length'
        res.set 'Access-Control-Expose-Headers', 'ETag'

        if query.uploads?
            upload_id = crypto.randomBytes(32).toString 'hex'
            res.send XMLAdapter.initiate_multipart_result(s_req.bucket, key, upload_id)
        else if query.uploadId?
            upload_id = query.uploadId[0]
            bucket_obj = @store.get_bucket(s_req.bucket)
            @store.combine_object_parts(bucket_obj, upload_id, s_req.object, @_parse_complete_multipart_upload(req), req).then (real_obj) ->
                res.send XMLAdapter.complete_multipart_result(s_req.bucket, real_obj, @hostname, @port)
        else if req.get('Content-Type').match(/^multipart\/form-data; boundary=(.+)/)?
            success_action_redirect = req.query['success_action_redirect']
            success_action_status = req.query['success_action_status']
            filename = 'default'
            bm = req.body.match /filename="(.*)"/
            if bm?
                filename = bm[1]
            key = key.replace /\$\{filename\}/g, filename
            bucket_obj = @store.get_bucket s_req.bucket
            unless bucket_obj?
                bucket_obj = @store.create_bucket(s_req.bucket).then (bucket_obj) ->
            q.all [bucket_obj], (res) ->
                [bucket_obj] = res
                store.store_object(bucket_obj, key, s_req.req).then (real_obj) ->
                    res.set 'ETag', "\"#{real_obj.md5}\""
                    if success_action_redirect?
                        res.set 'Location', success_action_redirect
                        res.status 307
                        res.end()
                    else
                        status_code = success_action_status || 304
                        res.status status_code
                        if status_code is 201
                            res.send XMLAdapter.complete_post_result(s_req.bucket, real_obj, @hostname, @port)
        else
            res.status 400
            res.send XMLAdapter.error
                code: 'BadRequest'
                message: 'We\'re not sure what you want :('
                Resource: ''

    do_DELETE: (req, res) ->
        if req.get('origin')? then res.set 'Access-Control-Allow-Origin', '*'
        s_req = _normalize_request req

        switch s_req.type
            when s_req.constructor.DELETE_OBJECT
                bucket_obj = @store.get_bucket s_req.bucket
                @store.delete_object bucket_obj, s_req.object, s_req.request
            when s_req.constructor.DELETE_BUCKET
                @store.delete_bucket s_req.bucket

        res.status 204
        res.end()

    do_OPTIONS: (req, res) ->
        res.set 'Access-Control-Allow-Origin' , '*'
        res.set 'Access-Control-Allow-Methods', 'PUT, POST, HEAD, GET, OPTIONS'
        res.set 'Access-Control-Allow-Headers', 'X-AMZ-ACL, X-AMZ-EXPIRES, X-AMZ-DATE, Authorization, Content-Length, Content-Type, ETag'
        res.set 'Access-Control-Expose-Headers', 'ETag'
        res.end()

    _normalize_delete: (req, s_req) ->
        path = req.path
        query = req.query
        if path is "/" and s_req.is_path_style
            # check later for 404
            return
        else
            if s_req.is_path_style
                elems = path.substring(1).split "/"
                s_req.bucket = elems[0]
            else
                elems = path.split "/"
            if elems.length == 0
                throw new Error("Unsupported operation")
            else if elems.length == 1
                s_req.type = s_req.constructor.DELETE_BUCKET
                s_req.query = query
            else
                s_req.type = s_req.constructor.DELETE_OBJECT
                object = elems[1..].join '/'
                s_req.object = object
        s_req

    _normalize_get: (req, s_req) ->
        path = req.path
        query = req.query
        if path is "/" and s_req.is_path_style
            s_req.type = s_req.constructor.LIST_BUCKETS
        else
            if s_req.is_path_style
                elems = path.substring(1).split "/"
                s_req.bucket = elems[0]
            else
                elems = path.split "/"
            if elems.length < 2
                s_req.type = s_req.constructor.LS_BUCKET
                s_req.query = query
            else
                if query.acl is ""
                    s_req.type = s_req.constructor.GET_ACL
                else
                    s_req.type = s_req.constructor.GET
                object = elems[1..].join '/'
                s_req.object = object
        s_req

    _normalize_put: (req, s_req) ->
        path = req.path
        if path is "/"
            if s_req.bucket?
                s_req.type = s_req.constructor.CREATE_BUCKET
        else
            if s_req.is_path_style
                elems = path.substring(1).split "/"
                s_req.bucket = elems[0]
                if elems.length is 1
                    s_req.type = s_req.constructor.CREATE_BUCKET
                else
                    if req.originalUrl.match /\?acl/
                        s_req.type = s_req.constructor.SET_ACL
                    else
                        s_req.type = s_req.constructor.STORE
                    s_req.object = elems[1..].join "/"
            else
                if req.originalUrl.match /\?acl/
                    s_req.type = s_req.constructor.SET_ACL
                else
                    s_req.type = s_req.constructor.STORE
                s_req.object = path[1...-1]

        # TODO: parse x-amz-copy-source-range:bytes=first-last header
        # for multipart copy
        copy_source = req.get 'x-amz-copy-source'
        if copy_source and copy_source.length is 1
            src_elems   = copy_source[0].split("/")
            if src_elems[0] == ""
                root_offset = 1
            else
                root_offset = 0
            s_req.src_bucket = src_elems[root_offset]
            s_req.src_object = src_elems[(1 + root_offset)..].join("/")
            s_req.type = s_req.constructor.COPY
            s_req.request = req
        s_req

    _normalize_post: (req, s_req) ->
        path = req.path
        s_req.path = req.query.key
        s_req.request = req
        if s_req.is_path_style
            elems = path[1..].split("/")
            s_req.bucket = elems[0]
            if elems.size >= 2
                s_req.object = elems[1...-1].join('/')
        else
            s_req.object = path[1...-1]
        s_req

    _normalize_request: (req) ->
        host = req.hostname

        s_req = new Request()
        s_req.path = req.baseUrl
        s_req.is_path_style = true

        if host in @root_hostnames
            s_req.is_path_style = true
        else
            s_req.bucket = host.split(".")[0]
            s_req.is_path_style = false

        s_req.http_verb = req.method

        # console.log req.method

        switch req.method
            when 'PUT' then s_req = @_normalize_put req, s_req
            when 'GET', 'HEAD' then s_req = @_normalize_get req, s_req
            when 'DELETE' then s_req = @_normalize_delete req, s_req
            when 'POST' then s_req = @_normalize_post req, s_req
            else throw new Error("Unknown request")

        s_req

    _parse_complete_multipart_upload: (req) ->
        doc = new DOM().parseFromString req.body
        nodes = doc.getElementsByTagName 'Part'
        parts = []
        nodes.forEach (part) ->
            parts.push
                number: part.getElementsByTagName('PartNumber')[0].data
                etag: part.getElementsByTagName('ETag')[0].data
        parts

    dump_request: (req) ->
        console.log "----------Dump Request-------------"
        console.log req.method
        console.log req.baseUrl
        for k, v of req
            console.log "#{k}: #{v}"
        console.log "----------End Dump -------------"

module.exports = Servlet

