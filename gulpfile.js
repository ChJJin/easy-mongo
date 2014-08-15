var gulp = require('gulp'),
    g    = require('gulp-load-plugins')();

gulp.task('build', function(){
  gulp.src('./src/*.coffee')
    .pipe(g.coffee({bare: true}).on('error', g.util.log))
    .pipe(gulp.dest('./lib'));
});

gulp.task('watch', function(){
  gulp.watch('./src/*.coffee', ['build'])
    .on('change', function(event) {
      console.log('File ' + event.path + ' was ' + event.type + ', running tasks...');
    });
});

gulp.task('default', ['build']);
