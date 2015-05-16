fs = require 'fs'
https = require 'https'
http = require 'http'
path = require 'path'
express = require 'express'
subdomain = require 'express-subdomain'
bodyparser = require 'body-parser'
multer = require 'multer'
q = require 'q'
Servlet = require './servlet'
FileStore = require '../file_system/file_store'
XMLAdapter = require './xml_adapter'

class S3Server

    constructor: (options) ->
        @port = options.port || 4567
        root = options.root || path.join(__dirname, '..', '..', 's3_root')
        sslCert = options.sslCert || null
        sslKey = options.sslKey || null
        @hostname = options.hostname || 'localhost'
        SSL = false
        if sslCert? and sslKey?
            port = 443
            SSL = true
        store = new FileStore root
        @servlet = new Servlet store, @hostname, @port
        app = express()
        router = express.Router()
        router.use (req, res, next) =>
            switch req.method
                when 'PUT' then @servlet.do_PUT req, res
                when 'GET', 'HEAD' then @servlet.do_GET req, res
                when 'DELETE' then @servlet.do_DELETE req, res
                when 'POST' then @servlet.do_POST req, res
            next()

        app.use subdomain('*', router)
        app.use router
        app.use bodyparser.json()
        app.use bodyparser.urlencoded({extended: false})
        app.use multer({dest: path.join(__dirname, '..', '..', 'tmp')}, router)

        if SSL
            try
                privateKey = fs.readFileSync config.sslKey
                certificate = fs.readFileSync config.sslCert
            catch error
                console.error "Unable to open SSL private key or cert"
                throw error
            @server = https.createServer
                key: privateKey,
                cert: certificate
            , app
        else
            @server = http.createServer app

    listen: ->
        d = q.defer()
        @server.listen @port, @hostname, 511, (err) =>
            if err? then throw err
            console.log "S3 Server running at #{@hostname}:#{@port}."
            d.resolve @
        @server.on 'error', (err) ->
            console.log err
        d.promise

module.exports = S3Server

