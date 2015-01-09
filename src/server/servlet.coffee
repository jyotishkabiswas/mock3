class Servlet

    constructor: (server, store, hostname) ->

        @server = server

        @store = store
        @hostname = hostname
        @port = server.config[port]
        @root_hostnames = [hostname,'localhost','s3.amazonaws.com','s3.localhost']

    do_GET: (req, res) ->
