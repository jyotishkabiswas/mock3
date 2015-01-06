#!/usr/bin/env node

fs = require 'fs'
https = require 'https'
http = require 'http'

_ = require 'lodash'
express = require 'express'
yargs = require 'yargs'


# Command line options.
argv = yargs
  .usage('A mock aws s3 server in the spirit of fake-s3 (https://github.com/jubos/fake-s3)\nUsage: $0 [options]')
  .describe('p', 'what port to run the server on - defaults to 4567')
  .alias('p', 'port')
  .describe('r', 'specify a directory to use for storage (required)')
  .alias('r','root')
  .string('r')
  .required('r', 'you must specify a directory to use for storage')
  .describe('c', 'specify a SSL certificate to be used by the server - requires that a private key also be specified and sets port to 443')
  .alias('c', 'cert')
  .string('c')
  .describe('k', 'specify a SSL private key to be used by the server - requires that a certificate also be supplied and sets port to 443')
  .alias('k', 'key')
  .string('k')
  .argv

SSL = false

defaultConfig =
  port: 4567
  rootDir: null
  sslCert: null
  sslKey: null

userConfig =
  port: argv.p
  rootDir: argv.r
  sslCert: argv.c
  sslKey: argv.k

if argv.c and not argv.k or argv.k and not argv.c
  throw new Error('You must specify both a private key and certificate for SSL')

config = _.defaults defaultConfig, userConfig

if argv.c and argv.k
  config.port = 443
  SSL = true

app = express()

app.get '/', (req, res) ->
  res.send 'Hello World!'

if SSL
  try
    privateKey = fs.readFileSync config.sslKey
    certificate = fs.readFileSync config.sslCert
  catch error
    console.error "Unable to open SSL private key or cert"
    throw error
  server = https.createServer
      key: privateKey,
      cert: certificate
    , app
else
  server = http.createServer(app)

server.listen(config.port)

console.log "Mock3 listening on #{config.port}"
