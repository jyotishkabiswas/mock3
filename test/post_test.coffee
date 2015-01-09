FS = require 'q-io/fs'
RestClient = require('node-rest-client').Client
should = require 'should'


url = 'http://posttest.localhost:10453/'
file = FS.rea

describe 'Post Test', ->

    describe 'test options', ->
        client = new RestClient url
        it 'access_control_allow_origin should be "*"', ->
            client.get url, (data, response) ->
                data.headers['access_control_allow_origin'].should.equal "*"

    describe 'test redirect', ->

        it 'successful post should rediriect', ->
            client = new RestClient()
            FS.read('__filename', 'rb').then (data) ->
                client.post @url, 
                    key: 'uploads/12345/#{__filename}'
                    'success_action_redirect': 'http://somewhere.else.com/'
                    'file': data
                , (data, response) ->
                    data.code.should.equal 307
                    data.headers.location.should.equal 'http://somewhere.else.com'

    describe 'test status 200', ->

        it 'successful post should respond with status 200', ->
            client = new RestClient()
            FS.read('__filename', 'rb').then (data) ->
                client.post @url, 
                    key: 'uploads/12345/#{__filename}'
                    success_action_status: '200'
                    file: data
                , (data, response) ->
                    data.code.should.equal 200
        
    describe 'test status 201', ->

        it 'successful post should respond with status 201', ->
            client = new RestClient()
            FS.read('__filename', 'rb').then (data) ->
                client.post @url, 
                    key: 'uploads/12345/#{__filename}'
                    success_action_status: '201'
                    file: data
                , (data, response) ->
                    data.code.should.equal 201



        
