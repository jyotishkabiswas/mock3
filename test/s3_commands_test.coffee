AWS = require 'aws-sdk'
should = require 'should'

s3 = new AWS.S3
    access_key_id: '123'
    secret_access_key: 'abc'
    s3_endpoing: 'localhost'
    s3_port: 10453
    use_ssl: false

describe 'S3 Commands Test', ->

    describe 'test create bucket', ->

        bucket = s3.createBucket 
            Bucket: "node_aws_s3"
        , (err, data) ->    
            if err? then throw err
            data?.should.be.true
            s3.bucketExists 
                Bucket: "node_aws_s3"
            , (err, data) ->
                if err? then throw err
                data.should.be.true
            bucket_names = []
            s3.listBuckets (err, data) ->
                if err? then throw err
                bucket_names.push name for name of data
                bucket_names.should.containEql "node_aws_s3"

    describe 'test destroy bucket', ->

        it 'bucket should not exist once deleted', ->
            s3.createBucket 
                Bucket: "deletebucket"
            , (err, data) ->
                if err? then throw err
                s3.deletebucket 
                    Bucket: "deletebucket"
                , (err, data) ->
                    if err? then throw err
                    s3.bucketExists
                        Bucket: "deletebucket"
                    , (err, data) ->
                        if err? then throw err
                        data.should.be.false

    describe 'test store', ->

        it 'bucket should contain correct value for stored object', ->
            s3.createBucket 
                Bucket: "node_aws_s3"
            , (err, data) ->
                if err? then throw err
                s3.putObject 
                    Bucket: "node_aws_s3"
                    Key: "Hello"
                    Body: "World"
                , (err, data) ->
                    if err? then throw err
                    s3.getObject 
                        Bucket: "node_aws_s3"
                        Key: "Object Key"
                    , (err, data) ->
                        if err? then throw err
                        data.body.should.be "World"

    describe 'test large store', ->

        it 'bucket should contain correct value for large stored object', ->
            s3.createBucket 
                Bucket: "node_aws_s3"
            , (err, data) ->
                if err? then throw err
                buf = new Buffer(50000)
                for i in [0...50000]
                    buf.write "i"
                s3.upload 
                    Bucket: "node_aws_s3"
                    Key: "Hello"
                    Body: buf
                , (err, data) ->
                    if err? then throw err
                    s3.getObject 
                        Bucket: "node_aws_s3"
                        Key: "Object Key"
                    , (err, data) ->
                        if err? then throw err
                        rbuf = new Buffer(50000)
                        for i in [0...50000]
                            rbuf.write "i"
                        data.body.should.equal rbuf

    describe 'test metadata store', ->

        it 'metadata should be stored and returned correctly', ->
            s3.createBucket
                Bucket: "node_aws_s3"
            , (err, data) ->
                if err? then throw err
                s3.putObject 
                    Bucket: "node_aws_s3"
                    Key: "Meta"
                    Body: "data"
                , (err, data) ->
                    if err? then throw err
                    s3.getObject 
                        Bucket: "node_aws_s3"
                        Key: "Meta"
                    , (err, data) ->
                        if err? then throw err
                        data.body.should.equal "data"
                        data.metadata.param1 = "one"
                        data.metadata.param2 = "two, three"
                        data.Bucket = "node_aws_s3"
                        data.Key = "Meta"
                        s3.putObject data, (err, data) ->
                            if err? then throw err
                            s3.getObject 
                                Bucket: "node_aws_s3"
                                Key: "Meta"
                            , (err, data) ->
                                if err? then throw err
                                data.metadata.param1.should.equal "one"
                                data.metadata.param2.should.equal "two, three"

    describe 'test object copy', ->

        it 'object body should be copied correctly', ->

            s3.createBucket
                Bucket: 'test_copy_to'
            , (err, data) ->
                if err? then throw err
                s3.createObject 
                    Bucket: 'test_copy_to'
                    Key: 'key1'
                    Body 'asdf'
                , (err, data) ->
                    if err? then throw err
                    s3.copyObject 
                        Bucket: 'test_copy_to'
                        CopySource: 'test_copy_to/key1'
                        Key: 'key2'
                    , (err, data) ->
                        if err? then throw err
                        s3.getObject 
                            Bucket: 'test_copy_to'
                            Key: 'key2'
                        , (err, data) ->
                            if err? then throw err
                            data.body.should.equal 'asdf'

    #TODO: rest of test and other tests
    describe 'test metadata copy', ->

        it 'object metadata should be copied correctly', ->











