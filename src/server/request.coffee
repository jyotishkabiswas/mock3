class Request
    CREATE_BUCKET: "CREATE_BUCKET"
    LIST_BUCKETS: "LIST_BUCKETS"
    LS_BUCKET: "LS_BUCKET"
    HEAD: "HEAD"
    STORE: "STORE"
    COPY: "COPY"
    GET: "GET"
    GET_ACL: "GET_ACL"
    SET_ACL: "SET_ACL"
    MOVE: "MOVE"
    DELETE_OBJECT: "DELETE_OBJECT"
    DELETE_BUCKET: "DELETE_BUCKET"

    constructor: ->
        @bucket = null
        @object = null
        @type = null
        @src_bucket = null
        @src_object = null
        @method = null
        @request = null
        @path = null
        @is_path_style = null
        @query = null
        @http_verb = null

    inspect: ->
        console.log "-----Inspect FakeS3 Request"
        console.log "Type: #{@type}"
        console.log "Is Path Style: #{@is_path_style}"
        console.log "Request Method: #{@method}"
        console.log "Bucket: #{@bucket}"
        console.log "Object: #{@object}"
        console.log "Src Bucket: #{@src_bucket}"
        console.log "Src Object: #{@src_object}"
        console.log "Query: #{@query}"
        console.log "-----Done"

module.exports = Request