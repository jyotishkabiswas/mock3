should = require 'should'
FS = require 'q-io/fs'
FileStore = require '../../src/file_system/file_store'
glob = require 'glob'

store = new FileStore FS.join __dirname,'../s3_root'

describe 'File Store Test', ->

    describe 'test create bucket', ->

        it 'bucket should be created', (done) ->

            store.create_bucket('fileStoreTest').then (bucket_obj) ->
                bucket_obj.name.should.equal 'fileStoreTest'
                obj = store.get_bucket('fileStoreTest')
                obj.name.should.equal 'fileStoreTest'
            .then ->
                glob FS.join(store.root, 'fileStoreTest'), (err, files) ->
                    FS.base(files[0]).should.equal 'fileStoreTest'
                    done()

    describe 'test delete bucket', ->

        it 'bucket should be deleted', (done) ->
            store.delete_bucket('fileStoreTest').then (res) ->
                bucket = store.get_bucket('fileStoreTest')
                bucket?.should.be.false
                done()
