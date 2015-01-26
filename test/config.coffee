path = require 'path'

config =
    port: 10453
    rootDir: path.join __dirname, 's3_root'
    sslCert: null
    sslKey: null
    hostname: 'localhost'

module.exports = config


