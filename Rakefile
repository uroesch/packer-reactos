# -----------------------------------------------------------------------------
# Libraries
# -----------------------------------------------------------------------------
require 'yaml'
require 'json'
require 'erb'
require 'ostruct'

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
BUILD        = Regexp.new(ENV.fetch('BUILD', '.*'))
PACKER_LOG   = ENV.fetch('PACKER_LOG', 1)
LOG_DIR      = 'logs'

# -----------------------------------------------------------------------------
# Methodds
# -----------------------------------------------------------------------------
def environment(dist_name)
  ENV['PACKER_LOG']      = PACKER_LOG.to_s
  ENV['PACKER_LOG_PATH'] = File.join(LOG_DIR, dist_name + ".log") 
end

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------
directory LOG_DIR

# -----------------------------------------------------------------------------
# Tasks
# -----------------------------------------------------------------------------
task :default => :build

desc "Clean JSON files and packer images"
task :clean_all => [:clean_images, :clean_logs]

desc "Clean logs"
task :clean_logs do
  rm_rf LOG_DIR
end

desc "Clean images"
task :clean_images do
  destination_dir.each do |dir| 
    rm_rf dir
  end
end

desc "Build OS images"
task :build => [LOG_DIR] do
  Rake::FileList['*.pkrvars.hcl'].each do |hcl|
    name = hcl.pathmap('%n').pathmap('%n')
    environment(name)
    next unless hcl =~ BUILD
    sh %(packer build ) + 
       %(-var-file="#{hcl}" ) +
       %(-only="*.#{name}" ) +
       %(reactos.pkr.hcl) do |ok,res| end
  end
end
