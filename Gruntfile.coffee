'use strict'

path = require 'path'

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
            src: [
                "test/filestore/*.coffee"
                "test/commands/s3_commands_test.coffee"
                # "test/commands/post_test.coffee"
            ]
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
            test_root: ['./test/s3_root']

        nodemon:
            dev:
                script: 'bin/mock3.js'
                options:
                    args: ["-r #{process.env.S3_ROOT || path.join __dirname, 's3_root'}", "-p 10453"]

        notify:
            test:
                options:
                    title: 'Testing complete'
                    message: 'All tests have been run.'
            serve:
                options:
                    title: 'Started s3 server'
                    message: 'Server is running at localhost.'

    grunt.registerTask 'test', [
        'clean:test_root'
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



