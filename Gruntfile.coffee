GruntVTEX = require 'grunt-vtex'
webpack = require 'webpack'

module.exports = (grunt) ->
  pkg = grunt.file.readJSON 'package.json'

  replaceMap = {}
  devReplaceMap = {}
  replaceMap["/front.payment-data/"] = "//io.vtex.com.br/#{pkg.name}/#{pkg.version}/"
  replaceMap["\<\!\-\-remove\-\-\>(.|\n)*\<\!\-\-endremove\-\-\>"] = ""

  linkReplace = (features, symlink, tags) -> (match, path, app, major) ->
    env = if grunt.option('stable') then 'stable' else 'beta'
    if symlink[app]
      console.log "link".blue, app, "->".blue, "local"
      return "/#{app}/#{path.replace('.min', '')}"
    else
      version = tags[app][env][major]
      console.log "link".blue, app, "->".blue, version
      return "//io.vtex.com.br/#{app}/#{version}/#{path}"

  devReplaceMap["\\{\\{ \\'(.*)\\' \\| vtex_io: \\'(.*)\\', (\\d) \\}\\}"] = linkReplace

  defaultConfig = GruntVTEX.generateConfig grunt, pkg,
    followHttps: true
    replaceMap: replaceMap
    devReplaceMap: devReplaceMap
    livereload: !grunt.option('no-lr')
    open: false
    copyIgnore: ['!**/*.coffee', '!**/*.less', '!script/**/*.html', '!script/**/*.js',
      '!script/{common,payment*,shipping,shipping/*,payment-group/*}']

  delete defaultConfig.watch.coffee

  externals =
    'appendTemplate': 'vtex.common.appendTemplate'
    'Module': 'vtex.common.Module'
    'Routable': 'vtex.common.Routable'
    'debug': 'vtex.common.debug'
    'Step': 'vtex.knockout.Step'
    'Translatable': 'vtex.i18n.Translatable'

  # Add custom configuration here as needed
  customConfig =
    webpack:
      options:
        module:
          loaders: [
            { test: /\.coffee$/, loader: "coffee-loader" }
            { test: /\.html$/, loader: "html-loader", query: {minimize: false} }
          ]
        devtool: "source-map"
      main:
        entry: "./src/script/payment-data.coffee"
        externals: externals
        output:
          path: "build/<%= relativePath %>/script/"
          filename: "payment-data-bundle.js"
      dist:
        plugins: [
          new webpack.optimize.UglifyJsPlugin(mangle: false)
        ]
        entry: "./src/script/payment-data.coffee"
        externals: externals
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
      less:
        options:
          livereload: false
        files: ['src/style/**/*.less']
        tasks: ['less']
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
    build: ['clean', 'jshint', 'webpack:demo', 'webpack:main', 'copy:main', 'copy:pkg', 'less']
    # Deploy tasks
    dist: ['clean', 'jshint', 'webpack:dist', 'copy:main', 'copy:pkg', 'less', 'copy:deploy'] # Dist - minifies files
    test: []
    vtex_deploy: ['shell:cp', 'shell:cp_br']
    # Development tasks
    dev: ['nolr', 'build', 'watch']
    default: ['build', 'connect', 'watch']
    devmin: ['dist', 'connect:http:keepalive'] # Minifies files and serve

  # Project configuration.
  grunt.config.init defaultConfig
  grunt.config.merge customConfig
  grunt.loadNpmTasks name for name of pkg.devDependencies when name[0..5] is 'grunt-' and name isnt 'grunt-vtex'
  grunt.registerTask taskName, taskArray for taskName, taskArray of tasks
