#!/usr/bin/env node

fs = require 'fs'
https = require 'https'
http = require 'http'

_ = require 'lodash'
express = require 'express'
yargs = require 'yargs'

S3Server = require './server/s3_server'


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
    .describe('h', 'specify a hostname for the server')
    .alias('h', 'host')
    .string('h')
    .argv

SSL = false

defaultConfig =
    port: 4567
    rootDir: null
    sslCert: null
    sslKey: null
    hostname: 'localhost'

userConfig =
    port: parseInt argv.p.trim()
    rootDir: argv.r.trim()
    sslCert: argv.c
    sslKey: argv.k
    hostname: argv.h

if argv.c and not argv.k or argv.k and not argv.c
    throw new Error('You must specify both a private key and certificate for SSL')

config = _.defaults userConfig, defaultConfig

server = new S3Server config
server.listen().then ->
    console.log "Mock3 listening on #{config.port}"
