# -----------------------------------------------------------------------------
# Libraries
# -----------------------------------------------------------------------------
require 'yaml'
require 'json'
require 'erb'
require 'ostruct'
require 'open-uri'
require 'digest'

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
BUILD           = Regexp.new(ENV.fetch('BUILD', '.*'))
PACKER_LOG      = ENV.fetch('PACKER_LOG', 1)
PACKER_LOG_PATH = ENV.fetch('PACKER_LOG_PATH', false)
FAIL_FAST       = ENV.fetch('FAIL_FAST', 'false')
LOG_DIR         = 'logs'
ISO_DIR         = 'iso/reactos'
ROS_DEV_URL     = 'https://iso.reactos.org/bootcd/'

# -----------------------------------------------------------------------------
# Methodds
# -----------------------------------------------------------------------------
def environment(dist_name)
  ENV['PACKER_LOG']      = PACKER_LOG.to_s
  if PACKER_LOG_PATH != false
    ENV['PACKER_LOG_PATH'] = PACKER_LOG_PATH
  else
    ENV['PACKER_LOG_PATH'] = File.join(LOG_DIR, dist_name + ".log")
  end
end

def pkr_vars
  variables = ENV.select { |k, _v| k.start_with?('PKR_VAR_') }
  variables.map do |key, value|
     '-var="%s=%s"' % [key.sub(%r{^PKR_VAR_}, ''), value]
  end.join(' ')
end

def download_iso_archive(url)
  cd ISO_DIR do
    archive = File.basename(url)
    return if File.exist?(archive) or File.exist?(archive.ext + '.iso')
    IO.copy_stream(URI.open(url), archive)
  end
end

def fetch_bootcd_url
  URI.open(ROS_DEV_URL) do |result|
    result.readlines.reverse.each do |line|
      next unless line =~ %r{reactos-bootcd-.*\.7z}
      return ROS_DEV_URL + line.gsub(%r{.*href=["'](.*?)["'].*}xs, '\1').strip
    end
  end
end

def iso_file(file_glob = '*.iso')
  cd ISO_DIR do
    Dir.glob(file_glob).sort[-1]
  end
end

def sha256sum(basename)
  path = File.join(ISO_DIR, basename)
  'sha256:' << Digest::SHA256.file(path).hexdigest
end

def inject_unattend(iso)
  iso_path = File.join(ISO_DIR, iso)
  sh %(xorriso ) +
     %(-overwrite on ) +
     %(-dev "#{iso_path}" ) +
     %(-boot_image "any" "replay" ) +
     %(-map_single unattend.inf /reactos/unattend.inf )
end

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------
directory LOG_DIR
directory ISO_DIR

# -----------------------------------------------------------------------------
# Tasks
# -----------------------------------------------------------------------------
task :default => :build

desc "Display help"
task :help do
  #Rake::TaskManager.record_task_metadata = true
  #Rake::Application.display_tasks_and_comments
  puts <<~HELP
    Usage:
      rake <options> [task] <VARS>   

    Variables: 
      BUILD=<pattern>
      PACKER_LOG_PATH=<path>
      PKR_VAR_<packer_variable>=<value>
  HELP
end

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

desc "Download zipped ISO"
task :download_iso => ISO_DIR do
  url = fetch_bootcd_url
  download_iso_archive(url)
end

desc "extract iso from archive"
task :extract_iso => :download_iso do
  cd ISO_DIR do
    Rake::FileList['*.7z'].each do |archive|
      sh %(7z x -y "#{archive}" )
      sh %(rm #{archive})
    end
  end
end

desc "Build OS images"
task :build => [LOG_DIR, :extract_iso] do
  Rake::FileList['*.pkrvars.hcl'].each do |hcl|
    name = hcl.pathmap('%n').pathmap('%n')
    environment(name)
    next unless hcl =~ BUILD
    file_glob = case hcl
                when %r{nightly} then '*-dev-*'
                when %r{rc} then '*-RC-*'
                else '*-release-*'
                end
    iso = iso_file(file_glob)
    inject_unattend(iso)
    sh %(packer build ) +
       %(-var-file="#{hcl}" ) +
       %(-var="iso_file=#{iso}" ) +
       %(-var="iso_checksum=#{sha256sum(iso)}" ) +
       %(#{pkr_vars} ) +
       %(-only="*.#{name}" ) +
       %(reactos.pkr.hcl) do |ok, res|
         exit res.exitstatus if FAIL_FAST == 'true' && ! ok
       end
  end
end
