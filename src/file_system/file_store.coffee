q = require 'q'
FS = require 'q-io/fs'
glob = require 'glob'
S3Object = require '../data_structures/s3_object'
Bucket = require '../data_structures/bucket'
RateLimitableFile = require './rate_limitable_file'
Crypto = require 'crypto'
yaml = require 'js-yaml'

class FileStore

    SHUCK_METADATA_DIR: ".mock3_matadataFFF"
    SUBSECOND_PRECISION: 3

    constructor: (root) ->

        @root = root
        @buckets = []
        @bucket_hash = {}

        glob FS.join(root, "*"), null, (err, files) ->
            if err? then throw err
            files.forEach (bucket) ->
                bucket_name = FS.base bucket
                bucket_obj = new Bucket bucket_name, new Date(), []
                @buckets.push bucket_obj
                @bucket_hash[bucket_name] = bucket_obj

    # Pass a rate limit in bytes per second
    rate_limit: (rate_limit) ->
        RateLimitableFile.prototype.rate_limit = rate_limit

    buckets: ->
        @buckets

    get_bucket_folder: (bucket) ->
        FS.join @root, bucket.name

    get_bucket: (bucket) ->
        @bucket_hash[bucket]

    create_bucket: (bucket) ->
        d = q.defer()
        FS.makeTree(FS.join(@root, bucket)).then () ->
            bucket_obj = new Bucket(bucket, new Date(), [])
            unless @bucket_hash[bucket]
                @buckets.push bucket_obj
                @bucket_hash[bucket] = bucket_obj
            d.resolve bucket_obj
        d

    delete_bucket: (bucket_name) ->
        bucket = @get_bucket bucket_name
        unless bucket?
            throw new NoSuchBucket()
        if bucket.objects.length > 0
            throw new BucketNotEmpty()
        FS.removeTree(@get_bucket_folder(bucket)).then () ->
            delete @bucket_hash[bucket_name]


    get_object: (bucket, object_name, request) ->
        d = q.defer()
        real_obj = new S3Object()
        obj_root = FS.join(root, bucket, object_name, @SHUCK_METADATA_DIR)
        data = FS.read FS.join(obj_root, "metadata") #, {encoding: 'utf8'}
        fd = RateLimitableFile.open FS.join(obj_root, "metadata"), 'r'
        stats = FS.stat FS.join(obj_root, "content")

        Q.all([data, fd, stats]).then (res) ->
            [data, fd, stats] = res
            metadata = yaml.load data
            real_obj.name = object_name
            real_obj.md5 = metadata.md5
            real_obj.content_type = metadata.content_type || "application/octet-stream"
            real_obj.io = fd
            real_obj.size = metadata.size
            real_obj.creation_date = stats.ctime.toISOString()
            real_obj.modified_date = metadata.modified_date || stats.mtime.toISOString()
            real_obj.custom_metadata = metadata.custom_metadata || {}
            d.resolve real_obj
        .fail (err) ->
            d.reject err

        d

    object_metadata: (bucket, object) ->

    copy_object: (src_bucket_name, src_name, dst_bucket_name, dst_name, request) ->
        d = q.defer()
        src_root = FS.join @root, src_bucket_name, src_name, SHUCK_METADATA_DIR
        src_metadata_filename = FS.join src_root, "metadata"
        src_metadata = null
        src_content_filename = null
        dst_filename = null
        metadata_dir = null
        content = null
        metadata = null

        # read metadata and create new directory
        FS.read(src_metadata_filename).then (data) ->
            src_metadata = yaml.load data
            src_content_filename = FS.join src_root, "content"
            dst_filename = FS.join @root, dst_bucket_name, dst_name
            metadata_dir = FS.join dst_filename, SHUCK_METADATA_DIR
            FS.makeTree dst_filename
        # create new metadata directory
        .then (res) ->
            FS.makeTree metadata_dir
        # open source files
        .then (res) ->
            content = FS.join metadata_dir, "content"
            metadata = FS.join metadata_dir, "metadata"
            if src_bucket_name isnt dst_bucket_name or src_name isnt dst_name
                src_content_file = FS.open src_content_filename, 'rb'
                src_metadata_file = FS.open src_metadata_filename, 'r'
                return Q.all [src_content_file, src_metadata_file]
        # read source files
        .then (res) ->
            unless res?
                d.resolve null
                return
            [src_content_file, src_metadata_file] = res
            data = src_content_file.read()
            meta = src_metadata_file.read()
            return Q.all [data, meta]
        # write destination files
        .then (res) ->
            [data, meta] = res
            data_written = FS.write content, data, 'wb'
            metadata_written = FS.write metadata, meta, 'w'
            return Q.all [data_written, metadata_written]
        # write new metadata if requested
        .then (res) ->
            metadata_directive = request.header["x-amz-metadata-directive"][0]
            if metadata_directive is "REPLACE"
                metadata_struct = @create_metadata content, request
                return FS.write metadata, yaml.dump(metadata_struct)
        # copy buckets in memory
        .then (res) ->
            src_bucket = get_bucket src_bucket_name
            dst_bucket = get_bucket dst_bucket_name
            src_bucket = src_bucket || create_bucket src_bucket_name
            dst_bucket = dst_bucket || create_bucket dst_bucket_name
            obj = new S3Object()
            obj.name = dst_name
            obj.md5 = src_metadata.md5
            obj.content_type = src_metadata.content_type
            obj.size = src_metadata.size
            obj.modified_date = src_metadata.modified_date
            src_obj = src_bucket.find src_name
            dst_bucket.add obj
            d.resolve obj
        .catch (err) ->
            d.reject err
        d

    store_object: (bucket, object_name, request) ->

    do_store_object: (bucket, object_name, filedata, request) ->

    delete_object: (bucket, object_name, request) ->

    combine_object_parts: (bucket, upload_id, object_name, parts, request) ->

    create_metadata: (content, request) ->

module.exports = FileStore        

