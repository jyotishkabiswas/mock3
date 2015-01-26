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
        glob FS.join(root, "*"), null, (err, files) =>
            if err? then throw err
            files.forEach (bucket) =>
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
        if @bucket_hash[bucket]?
            d.resolve @get_bucket(bucket)
            return d.promise
        FS.makeTree(FS.join(@root, bucket)).then (res) =>
            bucket_obj = new Bucket bucket, new Date(), []
            unless @bucket_hash[bucket]?
                @buckets.push bucket_obj
                @bucket_hash[bucket] = bucket_obj
            d.resolve bucket_obj
        .catch (err) ->
            console.log err.stack
            d.reject err
        d.promise

    delete_bucket: (bucket_name) ->
        bucket = @get_bucket bucket_name
        unless bucket?
            throw new NoSuchBucket()
        if bucket.objects.length > 0
            throw new BucketNotEmpty()
        FS.removeTree(@get_bucket_folder(bucket)).then (res) =>
            delete @bucket_hash[bucket_name]


    get_object: (bucket, object_name, request) ->
        d = q.defer()

        if req.get("range")?[0]
            res.status 206
            range = req.get("range")[0].match /bytes=(\d*)-(\d*)/
            if range?.length > 0
                start = parseInt range[1]
                finish = parseInt range[2]
                fd = RateLimitableFile.open FS.join(obj_root, "content"),
                    flags: 'rb'
                    begin: start
                    end: finish
        real_obj = new S3Object()
        obj_root = FS.join(root, bucket, object_name, @SHUCK_METADATA_DIR)
        data = FS.read FS.join(obj_root, "metadata"), 'r' #, {encoding: 'utf8'}
        unless fd?
            fd = RateLimitableFile.open FS.join(obj_root, "content"), 'rb'
        stats = FS.stat FS.join(obj_root, "content")

        q.all([data, fd, stats]).spread (data, fd, stats) ->
            metadata = yaml.load data
            real_obj.name = object_name
            real_obj.md5 = metadata.md5
            real_obj.content_type = metadata.content_type || "application/octet-stream"
            real_obj.io = fd
            real_obj.size = metadata.size || 0
            real_obj.creation_date = stats.ctime.toISOString()
            real_obj.modified_date = metadata.modified_date || stats.mtime.toISOString()
            real_obj.custom_metadata = metadata.custom_metadata || {}
            # real_obj.root = obj_root
            d.resolve real_obj
        .fail (err) ->
            d.reject err
        d.promise

    object_metadata: (bucket, object) ->

    copy_object: (src_bucket_name, src_name, dst_bucket_name, dst_name, request) ->
        d = q.defer()
        src_root = FS.join @root, src_bucket_name, src_name, @SHUCK_METADATA_DIR
        src_metadata_filename = FS.join src_root, "metadata"
        src_metadata = null
        src_content_filename = null
        dst_filename = null
        metadata_dir = null
        content = null
        metadata = null

        # read metadata and create new directory
        FS.read(src_metadata_filename).then (data) =>
            src_metadata = yaml.load data
            src_content_filename = FS.join src_root, "content"
            dst_filename = FS.join @root, dst_bucket_name, dst_name
            metadata_dir = FS.join dst_filename, @SHUCK_METADATA_DIR
            FS.makeTree dst_filename
        # create new metadata directory
        .then (res) ->
            FS.makeTree metadata_dir
        # copy files
        .then (res) ->
            content = FS.join metadata_dir, "content"
            metadata = FS.join metadata_dir, "metadata"
            if src_bucket_name isnt dst_bucket_name or src_name isnt dst_name
                src_content_copied = FS.copy src_content_filename, content
                src_metadata_copied = FS.copy src_metadata_filename, metadata
                return q.all [src_content_copied, src_metadata_copied]
        # write new metadata if requested
        .then (res) =>
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
        d.promise

    store_object: (bucket, object_name, req) ->
        d = q.defer()

        unless req.files?.length == 1
            d.reject 'Bad Request'
            return
        file = req.files[0]

        @_do_store_object(bucket, object_name, file, req).then (res) ->
            d.resolve res
        .fail (err) ->
            d.reject err

        d.promise

    _do_store_object: (bucket, object_name, file, req) ->
        d = q.defer()

        filename = FS.join @root, bucket.name, object_name
        metadata_dir = FS.join filename, @SHUCK_METADATA_DIR
        content  = FS.join filename, @SHUCK_METADATA_DIR, "content"
        metadata = FS.join filename, @SHUCK_METADATA_DIR, "metadata"
        obj = null

        FS.makeTree(filename).then (res) ->
            FS.makeTree metadata_dir
        .then (res) ->
            FS.copy file.path, content
        .then (res) =>
            FS.remove file.path
            @create_metadata content, req
        .then (metadata_struct) ->
            obj = new S3Object()
            obj.name = object_name
            obj.md5 = metadata_struct.md5
            obj.content_type = metadata_struct.content_type
            obj.size = metadata_struct.size
            obj.modified_date = metadata.modified_date
            # obj.root = metadata_dir
            bucket.add obj
            FS.write metadata, data, 'w'
        .then (res) ->
            d.resolve obj
        .catch (err) ->
            d.reject err
        d.promise

    _append_part: (tmp_path, part_path) ->
        d = q.defer()

        filename = FS.join @root, bucket.name, object_name
        metadata_dir = FS.join filename, @SHUCK_METADATA_DIR
        content  = FS.join filename, @SHUCK_METADATA_DIR, "content"
        metadata = FS.join filename, @SHUCK_METADATA_DIR, "metadata"

        content_path = FS.join part_path, @SHUCK_METADATA_DIR, 'content'
        FS.read(content_path, 'rb').then (data) ->
            FS.append content, data
        .then (res) ->
            d.resolve true
        .catch (err) ->
            d.reject err

        d.promise

    combine_object_parts: (bucket, upload_id, object_name, parts, request) ->
        d = q.defer()

        upload_path = FS.join @root, bucket.name
        base_path = FS.join upload_path, "#{upload_id}_#{object_name}"

        filename = FS.join @root, bucket.name, object_name
        metadata_dir = FS.join filename, @SHUCK_METADATA_DIR
        content  = FS.join filename, @SHUCK_METADATA_DIR, "content"
        metadata = FS.join filename, @SHUCK_METADATA_DIR, "metadata"

        part_paths = []
        content_paths = []

        tmp_path = null
        obj = null

        parts.sort (a, b) ->
            a.part_number - b.part_number

        for part in parts
            part_path = "#{base_path}_part#{part.number}"
            content_path = FS.join part_path, @SHUCK_METADATA_DIR, 'content'
            part_paths.push part_path
            content_paths.push content_path

        # check md5 hashes
        q.all([_md5digest(path) for path in content_paths]).then (res) =>
            for md5, i  in res
                if parts[i] isnt md5
                    throw new Error "Invalid part"
            tmp_path = FS.join @root, 'tmp', "#{bucket.name}_#{upload_id}_#{object_name}"
            FS.makeTree tmp_path
        # append parts to tmp file
        .then (res) =>
            funcs = []
            for part_path in part_paths
                func = () =>
                    @_append_part(tmp_path, part_path)
                funcs.push func
            funcs.reduce Q.when, q(initialVal)
        # copy over tmp file and metadata
        .then (res) =>
            @_do_store_object bucket, object_name, {path: tmp_path}, req
        # clean up parts
        .then (real_obj) =>
            obj = real_obj
            q.all [@delete_object(bucket, "#{upload_id}_#{object_name}_part#{part.number}", req) for part in parts]
        # remove base directory for upload
        .then (res) ->
            FS.removeTree base_path
        # clean up tmp file
        .then (res) ->
            FS.removeTree tmp_path
        # resolve object
        .then (res) ->
            d.resolve obj
        .catch (err) ->
            d.reject err

        d.promise

    delete_object: (bucket, object_name, request) ->
        d = q.defer()

        filename = FS.join @root, bucket.name, object_name
        FS.removeTree(filename).then (res) ->
            object = bucket.find object_name
            bucket.remove object
            d.resolve true
        .catch (err) ->
            d.reject err

        d.promise

    # TODO: get metadata from request.
    _create_metadata: (content, request) ->

        d = q.defer()
        metadata = {}
        @_md5digest(content).then (md5) ->
            metadata.md5 = md5
            FS.stat content
        .then (stats) ->
            metadata.size = stats.size
            metadata.modified_date = stats.mtime.toISOString()
            metadata.content_type = req.get 'content-type'
            metadata.custom_metadata = {}
            for k, v of req.headers
                match = k.match /^x-amz-meta-(.*)$/
                if match?[1]?
                    match_key = match[1]
                    metadata.custom_metadata[match_key] = v.join ', '
            d.resolve metadata
        .catch (err) ->
            d.reject err

        d.promise

    _md5digest: (filepath) ->
        m = q.defer()
        md5sum = Crypto.createHash 'md5'
        FS.read(filepath, 'rb').then (data) ->
            md5sum.update data
            m.resolve md5sum.digest('hex')
        .fail (err) ->
            m.reject err
        m.promise

module.exports = FileStore

