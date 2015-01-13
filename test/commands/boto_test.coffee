exec = require('child_process').exec
q = require 'q'
FS = require 'q-io/fs'
should = require 'should'


cmdpath = FS.absolute FS.join(__dirname, 'botocmd.py')
botocmd = "python #{cmdpath} -t localhost -p 10453"

describe 'Boto Test', ->

    describe 'test store', ->

        FS.open(__filename, 'rb').then (fd) ->
            fd.read()
        .then (data) ->
            FS.write('/tmp/fakes3_upload', 'wb')
        .then (res) ->
            d = q.defer()
            exec "#{@botocmd} put /tmp/fakes3_upload s3://s3cmd_bucket/upload", (err, stdout, stderr) ->
                if err?
                    console.log 'exec error: #{err}'
                stdout.should.match /stored/
                d.resolve FS.removeTree "/tmp/fakes3_upload"
            d
        .catch (err) ->
            throw err

