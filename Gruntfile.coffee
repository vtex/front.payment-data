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

  # Add custom configuration here as needed
  customConfig =
    concat:
      templates:
        options:
          process: (src) ->
            body = src.replace(/(\r\n|\n|\r)/g, "").replace(/\"/g, "\\\"")
            return "document.body.innerHTML+='#{body}';"
        src: 'src/templates/**/*.html'
        dest: "build/<%= relativePath %>/script/payment-data-templates.js"
      bundle:
        src: ["build/<%= relativePath %>/script/payment-data-templates.js",
              "build/<%= relativePath %>/script/payment-data.js"]
        dest: "build/<%= relativePath %>/script/payment-data-bundle.js"

    webpack:
      options:
        module:
          loaders: [
            test: /\.coffee$/, loader: "coffee-loader"
          ]
      main:
        entry: "./src/script/payment-data.coffee"
        output:
          path: "build/<%= relativePath %>/script/"
          filename: "payment-data.js"

    watch:
      coffee:
        files: ['src/script/**/*.coffee']
        tasks: ['coffeelint', 'webpack', 'concat:bundle']

  tasks =
    # Building block tasks
    build: ['clean', 'jshint', 'concat:templates', 'copy:main', 'copy:pkg', 'coffeelint', 'recess', 'less', 'webpack', 'concat:bundle']
    min: [] # minifies files
    # Deploy tasks
    dist: ['build', 'min', 'copy:deploy'] # Dist - minifies files
    test: []
    vtex_deploy: ['shell:cp']
    # Development tasks
    default: ['build', 'connect', 'watch']
    devmin: ['build', 'min', 'connect:http:keepalive'] # Minifies files and serve

  # Project configuration.
  grunt.config.init defaultConfig
  grunt.config.merge customConfig
  grunt.loadNpmTasks name for name of pkg.devDependencies when name[0..5] is 'grunt-' and name isnt 'grunt-vtex'
  grunt.registerTask taskName, taskArray for taskName, taskArray of tasks
