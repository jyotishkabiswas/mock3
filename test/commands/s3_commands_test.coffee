AWS = require 'aws-sdk'
should = require 'should'
config = require '../config'
S3Server = require '../../src/server/s3_server'

server = new S3Server config

server.listen().then (res) ->

    s3 = new AWS.S3
        accessKeyId: '123'
        secretAccessKey: 'abc'
        endpoint: 'localhost:10453'
        sslEnabled: false

    describe 'S3 Commands Test', ->

        describe 'test create bucket', ->

            it 'bucket should be created from request', (done) ->
                bucket = s3.createBucket
                    Bucket: "s3_commands_test"
                , (err, data) ->
                    if err? then throw err
                    s3.listBuckets {}, (err, data) ->
                        if err? then throw err
                        data.Buckets[0].Name.should.equal "s3_commands_test"
                        done()

        describe 'test delete bucket', ->

            it 'bucket should not exist once deleted', (done) ->
                s3.createBucket
                    Bucket: "deletebucket"
                , (err, data) ->
                    if err? then throw err
                    s3.deleteBucket
                        Bucket: "deletebucket"
                    , (err, data) ->
                        if err? then throw err
                        s3.listBuckets {}, (err, data) ->
                            if err? then throw err
                            data.Buckets.should.be.empty
                            done()

        # describe 'test store', ->

        #     it 'bucket should contain correct value for stored object', (done) ->
        #         s3.createBucket
        #             Bucket: "s3_commands_test"
        #         , (err, data) ->
        #             if err? then throw err
        #             s3.putObject
        #                 Bucket: "s3_commands_test"
        #                 Key: "Hello"
        #                 Body: "World"
        #             , (err, data) ->
        #                 if err? then throw err
        #                 s3.getObject
        #                     Bucket: "s3_commands_test"
        #                     Key: "Object Key"
        #                 , (err, data) ->
        #                     if err? then throw err
        #                     data.body.should.be "World"
        #                     done()

        # describe 'test large store', ->

        #     it 'bucket should contain correct value for large stored object', (done) ->
        #         s3.createBucket
        #             Bucket: "s3_commands_test"
        #         , (err, data) ->
        #             if err? then throw err
        #             buf = new Buffer(50000)
        #             for i in [0...50000]
        #                 buf.write "i"
        #             s3.upload
        #                 Bucket: "s3_commands_test"
        #                 Key: "Hello"
        #                 Body: buf
        #             , (err, data) ->
        #                 if err? then throw err
        #                 s3.getObject
        #                     Bucket: "s3_commands_test"
        #                     Key: "Object Key"
        #                 , (err, data) ->
        #                     if err? then throw err
        #                     rbuf = new Buffer(50000)
        #                     for i in [0...50000]
        #                         rbuf.write "i"
        #                     data.body.should.equal rbuf
        #                     done()

        # describe 'test metadata store', ->

        #     it 'metadata should be stored and returned correctly', (done) ->
        #         s3.createBucket
        #             Bucket: "s3_commands_test"
        #         , (err, data) ->
        #             if err? then throw err
        #             s3.putObject
        #                 Bucket: "s3_commands_test"
        #                 Key: "Meta"
        #                 Body: "data"
        #             , (err, data) ->
        #                 if err? then throw err
        #                 s3.getObject
        #                     Bucket: "s3_commands_test"
        #                     Key: "Meta"
        #                 , (err, data) ->
        #                     if err? then throw err
        #                     data.body.should.equal "data"
        #                     data.metadata.param1 = "one"
        #                     data.metadata.param2 = "two, three"
        #                     data.Bucket = "s3_commands_test"
        #                     data.Key = "Meta"
        #                     s3.putObject data, (err, data) ->
        #                         if err? then throw err
        #                         s3.getObject
        #                             Bucket: "s3_commands_test"
        #                             Key: "Meta"
        #                         , (err, data) ->
        #                             if err? then throw err
        #                             data.metadata.param1.should.equal "one"
        #                             data.metadata.param2.should.equal "two, three"
        #                             done()

        # describe 'test object copy', ->

        #     it 'object body should be copied correctly', (done) ->

        #         s3.createBucket
        #             Bucket: 'test_copy_to'
        #         , (err, data) ->
        #             if err? then throw err
        #             s3.createObject
        #                 Bucket: 'test_copy_to'
        #                 Key: 'key1'
        #                 Body 'asdf'
        #             , (err, data) ->
        #                 if err? then throw err
        #                 s3.copyObject
        #                     Bucket: 'test_copy_to'
        #                     CopySource: 'test_copy_to/key1'
        #                     Key: 'key2'
        #                 , (err, data) ->
        #                     if err? then throw err
        #                     s3.getObject
        #                         Bucket: 'test_copy_to'
        #                         Key: 'key2'
        #                     , (err, data) ->
        #                         if err? then throw err
        #                         data.body.should.equal 'asdf'

        # #TODO: rest of test and other tests
        # describe 'test metadata copy', ->

        #     it 'object metadata should be copied correctly', (done) ->











