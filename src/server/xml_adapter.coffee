XML = require 'xmlbuilder'

xmldec =
    version: '1.0'
    encoding: 'UTF-8'

XMLAdapter =

    buckets: (bucket_objs) ->
        xml = XML.create 'ListAllMyBucketsResult', xmldec
        xml.att xmlns: "http://s3.amazonaws.com/doc/2006-03-01/"
        owner = xml.ele('Owner')
        owner.ele 'ID', '123'
        owner.ele 'DisplayName', 'mock3'
        bl = xml.ele 'Buckets'
        bucket_objs.forEach (bucket) ->
            b = bl.ele 'Bucket'
            b.ele 'Name', bucket.name
            b.ele 'CreationDate', bucket.creation_date.toISOString()
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    # <?xml version="1.0" encoding="UTF-8"?>
    # <Error>
    #     <Code>NoSuchKey</Code>
    #     <Message>The resource you requested does not exist</Message>
    #     <Resource>/mybucket/myfoto.jpg</Resource>
    #     <RequestId>4442587FB7D0A2F9</RequestId>
    # </Error>
    error: (err) ->
        xml = XML.create 'Error', xmldec
        xml.ele 'Code', err.code
        xml.ele 'Message', err.message
        xml.ele 'Resource', err.resource
        xml.ele 'RequestId', 1
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    error_no_such_bucket: (name) ->
        xml = XML.create 'Error', xmldec
        xml.ele 'Code', 'NoSuchBucket'
        xml.ele 'Message', 'The resource you requested does not exist.'
        xml.ele 'Resource', name
        xml.ele 'RequestId', 1
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    error_bucket_not_empty: (name) ->
        xml = XML.create 'Error', xmldec
        xml.ele 'Code', 'BucketNotEmpty'
        xml.ele 'Message', 'The bucket you tried to delete is not empty.'
        xml.ele 'Resource', name
        xml.ele 'RequestId', 1
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    error_no_such_key: (name) ->
        xml = XML.create 'Error', xmldec
        xml.ele 'Code', 'NoSuchKey'
        xml.ele 'Message', 'The specified key does not exist.'
        xml.ele 'Resource', name
        xml.ele 'RequestId', 1
        xml.ele 'HostId', 2
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    bucket: (bucket) ->
        xml = XML.create 'ListBucketResult', xmldec
        xml.att xmlns: "http://s3.amazonaws.com/doc/2006-03-01/"
        xml.ele 'Name', bucket.name
        xml.ele 'Prefix'
        xml.ele 'Marker'
        xml.ele 'MaxKeys', '1000'
        xml.ele 'IsTruncated', 'false'
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    # A bucket query gives back the bucket along with contents
    # <Contents>
    #     <Key>Nelson</Key>
    #     <LastModified>2006-01-01T12:00:00.000Z</LastModified>
    #     <ETag>&quot;828ef3fdfa96f00ad9f27c383fc9ac7f&quot;</ETag>
    #     <Size>5</Size>
    #     <StorageClass>STANDARD</StorageClass>
    #     <Owner>
    #         <ID>bcaf161ca5fb16fd081034f</ID>
    #         <DisplayName>webfile</DisplayName>
    #      </Owner>
    # </Contents>
    _append_objects_to_list_bucket_result: (lbr, objects) ->
        unless objects?.length > 0
            return

        objects.forEach (obj) ->
            contents = lbr.ele 'Contents'
            contents.ele 'Key', obj.name
            contents.ele 'LastModified', obj.modified_date
            contents.ele 'ETag', "\"#{obj.md5}\""
            contents.ele 'Size', obj.size
            contents.ele 'StorageClass', 'STANDARD'
            owner = contents.ele 'Owner'
            owner.ele 'ID', 'abc'
            owner.ele 'DisplayName', 'You'

    bucket_query: (bucket_query) ->
        bucket = bucket_query.bucket
        xml = XML.create 'ListBucketResult', xmldec
        xml.att xmlns: "http://s3.amazonaws.com/doc/2006-03-01/"
        xml.ele 'Name', bucket.name
        xml.ele 'Prefix', bucket_query.prefix
        xml.ele 'Marker', bucket_query.marker
        xml.ele 'MaxKeys', bucket_query.max_keys
        xml.ele 'IsTruncated', bucket_query.is_truncated
        @_append_objects_to_list_bucket_result xml, bucket_query.matches
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    # Access Control List xml
    acl: (object=null) ->
        xml = XML.create 'AccessControlPolicy', xmldec
        xml.att xmlns: "http://s3.amazonaws.com/doc/2006-03-01/"
        owner = xml.ele 'Owner'
        owner.ele 'ID', 'abc'
        owner.ele 'DisplayName', 'You'
        acl = xml.ele 'AccessControlList'
        grant = acl.ele 'Grant'
        grantee = grant.ele 'Grantee', {"xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance", "xsi:type": "CanonicalUser"}
        grantee.ele 'ID', 'abc'
        grantee.ele 'DisplayName', 'You'
        grant.ele 'Permission', 'FULL_CONTROL'
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    # <CopyObjectResult>
    #     <LastModified>2009-10-28T22:32:00</LastModified>
    #     <ETag>"9b2cf535f27731c974343645a3985328"</ETag>
    # </CopyObjectResult>
    copy_object_result: (object) ->
        xml = XML.create 'CopyObjectResult', xmldec
        xml.ele 'LastModified', object.modified_date # .toISOString()
        xml.ele 'ETag', "\"#{object.md5}\""
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    # <?xml version="1.0" encoding="UTF-8"?>
    # <InitiateMultipartUploadResult>
    #     <Bucket>#{ s_req.bucket }</Bucket>
    #     <Key>#{ key }</Key>
    #     <UploadId>#{ upload_id }</UploadId>
    # </InitiateMultipartUploadResult>
    initiate_multipart_result: (bucket, key, upload_id) ->
        xml = XML.create 'InitiateMultipartUploadResult', xmldec
        xml.ele 'Bucket', bucket
        xml.ele 'Key', key
        xml.ele 'UploadId', upload_id
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    # <CompleteMultipartUploadResult>
    #     <Location>http://Example-Bucket.s3.amazonaws.com/Example-Object</Location>
    #     <Bucket>Example-Bucket</Bucket>
    #     <Key>Example-Object</Key>
    #     <ETag>"3858f62230ac3c915f300c664312c11f-9"</ETag>
    # </CompleteMultipartUploadResult>
    complete_multipart_result: (bucket, object, hostname, port) ->
        xml = XML.create 'CompleteMultipartUploadResult', xmldec
        portNum = ""
        if port? then portNum = ":#{port}"
        host = hostname || "localhost"
        xml.ele 'Location', "http://#{bucket}.#{host}#{portNum}/#{key}"
        xml.ele 'Bucket', 'bucket'
        xml.ele 'Key', object.name
        xml.ele 'ETag', "\"#{object.md5}\""
        xml.end { pretty: true, indent: '  ', newline: '\n' }

    # <?xml version="1.0" encoding="UTF-8"?>
    # <PostResponse>
    #     <Location>http://#{s_req.bucket}.localhost:#{@port}/#{key}</Location>
    #     <Bucket>#{s_req.bucket}</Bucket>
    #     <Key>#{key}</Key>
    #     <ETag>#{response['Etag']}</ETag>
    # </PostResponse>
    complete_post_result: (bucket, object, hostname, port) ->
        xml = XML.create 'PostResponse', xmldec
        portNum = ""
        if port? then portNum = ":#{port}"
        host = hostname || "localhost"
        xml.ele 'Location', "http://#{bucket}.#{host}#{portNum}/#{key}"
        xml.ele 'Bucket', bucket
        xml.ele 'Key', key


module.exports = XMLAdapter