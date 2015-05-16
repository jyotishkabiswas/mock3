path = require 'path'

config =
    port: 10453
    rootDir: path.join __dirname, 'test_root'
    sslCert: null
    sslKey: null
    hostname: 'localhost'

module.exports = config


