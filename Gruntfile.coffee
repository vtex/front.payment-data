GruntVTEX = require 'grunt-vtex'

module.exports = (grunt) ->
  pkg = grunt.file.readJSON 'package.json'

  replaceMap = {}
  replaceMap["/front.payment-data/"] = "//io.vtex.com.br/#{pkg.name}/#{pkg.version}/"
  replaceMap["\<\!\-\-remove\-\-\>(.|\n)*\<\!\-\-endremove\-\-\>"] = ""

  defaultConfig = GruntVTEX.generateConfig grunt, pkg,
    followHttps: true
    replaceMap: replaceMap
    livereload: !grunt.option('no-lr')
    open: false
    copyIgnore: ['!**/*.coffee', '!**/*.less', '!script/**/*.html', '!script/**/*.js']

  delete defaultConfig.watch.coffee

  # Add custom configuration here as needed
  customConfig =
    webpack:
      options:
        module:
          loaders: [
            { test: /\.coffee$/, loader: "coffee-loader" }
            { test: /\.html$/, loader: "html-loader" }
          ]
      main:
        entry: "./src/script/payment-data.coffee"
        output:
          path: "build/<%= relativePath %>/script/"
          filename: "payment-data-bundle.js"
      demo:
        entry: "./src/script/demo.js"
        output:
          path: "build/<%= relativePath %>/script/"
          filename: "demo.js"

    watch:
      coffee:
        files: ['src/script/**/*.coffee']
        tasks: ['webpack']
      kotemplates:
        files: ['src/script/**/*.html']
        tasks: ['webpack']
      script:
        files: ['src/script/**/*.js']
        tasks: ['jshint', 'webpack']
      main:
        files: ['src/i18n/**/*.json',
                'src/img/**/*',
                'src/lib/**/*',
                'src/index.html']
        tasks: ['jshint', 'copy:main', 'getTags', 'copy:dev']

  tasks =
    # Building block tasks
    build: ['clean', 'jshint', 'copy:main', 'copy:pkg', 'recess', 'less', 'webpack']
    min: [] # minifies files
    # Deploy tasks
    dist: ['build', 'min', 'copy:deploy'] # Dist - minifies files
    test: []
    vtex_deploy: ['shell:cp']
    # Development tasks
    dev: ['nolr', 'build', 'watch']
    default: ['build', 'connect', 'watch']
    devmin: ['build', 'min', 'connect:http:keepalive'] # Minifies files and serve

  # Project configuration.
  grunt.config.init defaultConfig
  grunt.config.merge customConfig
  grunt.loadNpmTasks name for name of pkg.devDependencies when name[0..5] is 'grunt-' and name isnt 'grunt-vtex'
  grunt.registerTask taskName, taskArray for taskName, taskArray of tasks
