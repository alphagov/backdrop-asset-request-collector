require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.pattern = 'test/**/*_test.rb'
end

BASEDIR = File.dirname(__FILE__)
INPUT_FILES = FileList["*.gz"]
OUTPUT_FILES = INPUT_FILES.map { |file| "processed/" + file.gsub(/\.gz$/,'.stats') }
rule %r{.*\.stats} => [->(outfile) { outfile.gsub(".stats", ".gz").gsub("processed/", "")} ] do |t|
  FileUtils.mkdir_p(File.dirname(t.name))
  sh "(gzcat #{t.source} | #{BASEDIR}/bin/process > #{t.name}.tmp) && mv #{t.name}.tmp #{t.name} "
end

desc "build all stats"
task :stats => OUTPUT_FILES

desc "Clean out built stats"
task :clean do
  OUTPUT_FILES.each do |f|
    File.unlink(f)
  end
end
