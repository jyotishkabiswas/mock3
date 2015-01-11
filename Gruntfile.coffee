'use strict'

module.exports = (grunt) ->

    # load grunt tasks
    (require 'matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks)

    _ = grunt.util._
    path = require 'path'

    grunt.initConfig
        pkg: grunt.file.readJSON 'package.json'
        dirs:
            s3server: 'src'

        coffeelint:
            gruntfile:
                src: '<%= watch.gruntfile.files %>'
            s3server:
                src: '<%= dirs.s3server %>/**/*.coffee'
            test:
                src: '<%= watch.test.files %>'
            options:
                configFile: 'coffeelint.json'

        mochaTest:
            src: ["test/**/*.coffee"]
            options:
                reporter: "spec"

        watch:
            options:
                spawn: false
            gruntfile:
                files: 'Gruntfile.coffee'
                tasks: ['coffeelint:gruntfile']
            test:
                files: ['test/**/*.coffee']
                tasks: ['mochaTest']
            s3server:
                files: ['src/**/*.coffee']
                tasks: ['coffeelint:s3server']

        clean:
            s3_root: ['./s3_root/*']

        nodemon:
            dev:
                script: 'index.js'
                options:
                    args: ["-r #{process.env.S3_ROOT || './s3_root'}", "-p 10453"]

        notify:
            test:
                options:
                    title: 'Testing complete'
            serve:
                options:
                    title: 'Started s3 server'

    grunt.registerTask 'test', [
        'clean'
        'coffeelint'
        'mochaTest'
        'notify:test'
    ]

    grunt.registerTask 'reset', [
        'clean'
    ]

    grunt.registerTask 'serve', [
        'nodemon'
        'notify:serve'
    ]

    grunt.registerTask 'default', [
        'reset'
        'test'
        'serve'
    ]



