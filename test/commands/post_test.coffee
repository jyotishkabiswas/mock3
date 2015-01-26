FS = require 'q-io/fs'
RestClient = require('node-rest-client').Client
should = require 'should'

# config = require '../config'
# S3Server = require '../../src/server/s3_server'

# server = new S3Server config

# server.listen().then (res) ->

url = 'http://localhost:10453'

describe 'Post Test', ->

    describe 'test options', ->
        it 'access_control_allow_origin should be "*"', (done) ->
            client = new RestClient()
            client.get url, (data, response) ->
                console.log response
                data.headers['access_control_allow_origin'].should.equal "*"
                done()

    describe 'test redirect', ->

        it 'successful post should redirect', (done) ->
            client = new RestClient()
            FS.read(__filename, 'rb').then (data) ->
                client.post @url,
                    key: 'uploads/12345/#{__filename}'
                    'success_action_redirect': 'http://somewhere.else.com/'
                    'file': data
                , (data, response) ->
                    data.code.should.equal 307
                    data.headers.location.should.equal 'http://somewhere.else.com'
                    done()

    describe 'test status 200', ->

        it 'successful post should respond with status 200', (done) ->
            client = new RestClient()
            FS.read(__filename, 'rb').then (data) ->
                client.post @url,
                    key: 'uploads/12345/#{__filename}'
                    success_action_status: '200'
                    file: data
                , (data, response) ->
                    data.code.should.equal 200
                    done()

    describe 'test status 201', ->

        it 'successful post should respond with status 201', (done) ->
            client = new RestClient()
            FS.read(__filename, 'rb').then (data) ->
                client.post @url,
                    key: 'uploads/12345/#{__filename}'
                    success_action_status: '201'
                    file: data
                , (data, response) ->
                    data.code.should.equal 201
                    done()




