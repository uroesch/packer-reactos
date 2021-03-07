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
TARGET          = ENV.fetch('TARGET', 'x86')
PACKER_LOG      = ENV.fetch('PACKER_LOG', 1)
PACKER_LOG_PATH = ENV.fetch('PACKER_LOG_PATH', false)
FAIL_FAST       = ENV.fetch('FAIL_FAST', 'false')
LOG_DIR         = 'logs'
ISO_DIR         = 'iso/reactos'
ROS_DEV_URL     = 'https://iso.reactos.org/bootcd/'
WINE_GECKO_URL  = 'https://svn.reactos.org/amine/wine_gecko-2.40-x86.msi'
WINE_GECKO_SHA1 = '8a3adedf3707973d1ed4ac3b2e791486abf814bd'

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

def download_file(url, target_dir = '.')
  cd target_dir do
    basename = File.basename(url)
    return if File.exist?(basename) or File.exist?(basename.ext + '.iso')
    IO.copy_stream(URI.open(url), basename)
  end
end

def fetch_bootcd_url(target = 'x86')
  URI.open(ROS_DEV_URL) do |result|
    result.readlines.reverse.each do |line|
      next unless line =~ %r{reactos-bootcd-.*\.7z}
      next unless line =~ %r{-#{target}-}
      return ROS_DEV_URL + line.gsub(%r{.*href=["'](.*?)["'].*}xs, '\1').strip
    end
  end
end

def iso_glob(hcl, target = 'x86')
  case hcl
  when %r{nightly} then "*-dev-*#{target}*"
  when %r{rc} then '*-RC-*'
  else '*-release-*'
  end
end

def iso_path(file_glob = '*.iso')
  cd ISO_DIR do
    Dir.glob(file_glob).sort[-1]
  end
end

def sha256sum(basename)
  path = File.join(ISO_DIR, basename)
  'sha256:' << Digest::SHA256.file(path).hexdigest
end

def modify_iso(iso)
  iso_path = Rake::FileList["**/#{iso}"].first
  # preparation for injecting wine_gecko
  # extract_file_from_iso(iso_path, '/reactos/reactos.cab', 'reactos.cab')
  inject_file_into_iso(iso_path, 'unattend.inf', '/reactos/unattend.inf')
end

def extract_file_from_iso(iso_path, iso_file, local_file)
  sh %(xorriso ) +
     %(-osirrox on ) +
     %(-indev "#{iso_path}" ) +
     %(-extract "#{iso_file}" "#{local_file}")
end

def inject_file_into_iso(iso_path, local_file, iso_file)
  sh %(xorriso ) +
     %(-overwrite on ) +
     %(-dev "#{iso_path}" ) +
     %(-boot_image "any" "replay" ) +
     %(-map_single "#{local_file}" "#{iso_file}")
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
      TARGET=x86|x64
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
  url = fetch_bootcd_url(TARGET)
  download_file(url, ISO_DIR)
end

desc "Download gecko engine"
task :download_gecko do
  # disabled for the time being
  # still working out some issues
  # download_file(WINE_GECKO_URL)
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
task :build => [LOG_DIR, :extract_iso, :download_gecko] do
  Rake::FileList['*.pkrvars.hcl'].each do |hcl|
    name = hcl.pathmap('%n').pathmap('%n')
    environment(name)
    next unless hcl =~ BUILD
    file_glob = iso_glob(hcl, TARGET)
    iso_file  = iso_path(file_glob)
    modify_iso(iso_file)
    sh %(packer build ) +
       %(-var-file="#{hcl}" ) +
       %(-var="target=#{TARGET}" ) +
       %(-var="iso_file=#{iso_file}" ) +
       %(-var="iso_checksum=#{sha256sum(iso_file)}" ) +
       %(#{pkr_vars} ) +
       %(-only="*.#{name}" ) +
       %(reactos.pkr.hcl) do |ok, res|
         exit res.exitstatus if FAIL_FAST == 'true' && ! ok
       end
  end
end
