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
TEMPLATE_DIR    = 'templates'
ROS_DEV_URL     = 'https://iso.reactos.org/bootcd/'
ROS_RC_URL      = 'https://sourceforge.net/projects/reactos/files/ReactOS/0.4.14/'
WINE_GECKO_URL  = 'https://svn.reactos.org/amine/wine_gecko-2.40-x86.msi'
WINE_GECKO_SHA1 = '8a3adedf3707973d1ed4ac3b2e791486abf814bd'
VIRTIO_ISO_URL  = 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso'

# -----------------------------------------------------------------------------
# Methodds
# -----------------------------------------------------------------------------

# manage environment variables passed to packer
def environment(dist_name)
  ENV['PACKER_LOG']      = PACKER_LOG.to_s
  if PACKER_LOG_PATH != false
    ENV['PACKER_LOG_PATH'] = PACKER_LOG_PATH
  else
    ENV['PACKER_LOG_PATH'] = File.join(LOG_DIR, dist_name + ".log")
  end
end

# parse the packer var files 'pkrvars.hcl'
# not fully bullet proof yet!
def parse_var_file(file)
  hcl_vars = {}
  begin
    File.exist?(file)
    content = File.read(file)
    # remove comments
    content = content.gsub(%r{/\*.*?\*/}m, '')
    content = content.gsub(%r{=\s*\[(.*?)\]}m) { |x| x.gsub(%r{\s*\n\s*}, '') }
    content.each_line do |line|
      line.strip!
      next if line.empty?
      next if line.start_with?(%r{#|//})
      key, value = line.split(%r{\s*=\s*})
      value = value.to_s.gsub(%r{^["']|["']$}, '')
      hcl_vars[key] = value
    end
  end
  # expand the parser to locals to get this value
  hcl_vars['dist_name'] = hcl_vars.values_at('name', 'version').join('_')
  hcl_vars
end

# Read environment variables starting with PKR_VAR_ and
# convert to command line switch
def pkr_vars
  variables = ENV.select { |k, _v| k.start_with?('PKR_VAR_') }
  variables.map do |key, value|
     '-var="%s=%s"' % [key.sub(%r{^PKR_VAR_}, ''), value]
  end.join(' ')
end

# write config file based on template
def write_config(var_file)
  @config = parse_var_file(var_file)
  glob = File.join(TEMPLATE_DIR, '*.erb')
  Rake::FileList[glob].each do |template|
    basename = File.basename(template.ext)
    content  = File.read(template)
    File.open(basename, 'w') do |fh|
      puts "Writing config file '#{basename}'"
      fh.write ERB.new(content, trim_mode: '>').result(binding)
    end
  end
end

# return the base name of a file taking into account
# the whacky sourceforge.net url.
def basename(url)
  # remove the '/download' from the sf url
  File.basename(url.sub(%r{/download$}, ''))
end

# derive the basename from the various reactos zip file names.
def iso_basename(basename)
  # construct the name after unpacking
  basename.ext.sub(%r{-iso$}, '') + '.iso'
end

# download a file to a directory
def download_file(url, target_dir = '.')
  cd target_dir do
    basename = basename(url)
    return if File.exist?(basename) or File.exist?(iso_basename(basename))
    puts "Downloading '#{url}' to '#{basename}'"
    IO.copy_stream(URI.open(url), basename)
  end
end

# determine the latest RC release URL
def fetch_rc_url
  URI.open(ROS_RC_URL) do |result|
    result.readlines.each do |line|
      next unless line =~ %r{href=.*-RC-.*-iso\.zip}
      return line.gsub(%r{.*href=["'](.*?)["'].*}xs, '\1').strip
    end
  end
end

# determine the latest nightly release URL
def fetch_nightly_url(target = 'x86')
  URI.open(ROS_DEV_URL) do |result|
    result.readlines.reverse.each do |line|
      next unless line =~ %r{reactos-bootcd-.*\.7z}
      next unless line =~ %r{-#{target}-}
      return ROS_DEV_URL + line.gsub(%r{.*href=["'](.*?)["'].*}xs, '\1').strip
    end
  end
end

# create an glob for the various ISO file naming conventions
def iso_glob(hcl, target = 'x86')
  case hcl
  when %r{nightly} then "*-dev-*#{target}*"
  when %r{rc} then '*-RC-*'
  else '*-release-*'
  end
end

# return the latest version of the ISO file in iso directory
def iso_path(file_glob = '*.iso')
  cd ISO_DIR do
    Dir.glob(file_glob).sort[-1]
  end
end

# create a sha256 sum from the target ISO file
def sha256sum(basename)
  path = File.join(ISO_DIR, basename)
  'sha256:' << Digest::SHA256.file(path).hexdigest
end

# modify the ISO file for unattended installation via file injection.
def modify_iso(iso)
  iso_path = Rake::FileList["**/#{iso}"].first
  # preparation for injecting wine_gecko
  # extract_file_from_iso(iso_path, '/reactos/reactos.cab', 'reactos.cab')
  inject_file_into_iso(iso_path, 'unattend.inf', '/reactos/unattend.inf')
end

# extract a particular file from the ISO
def extract_file_from_iso(iso_path, iso_file, local_file)
  sh %(xorriso ) +
     %(-osirrox on ) +
     %(-indev "#{iso_path}" ) +
     %(-extract "#{iso_file}" "#{local_file}")
end

# inject a modified file into the ISO / may overwrite existing file.
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

desc "Clean up everything (disk images, logs, old iso files)"
task :clean_all => [:clean_logs, :clean_isos]

desc "Clean logs"
task :clean_logs do
  rm_rf LOG_DIR
end

desc "Clean outdated ISO images"
task :clean_isos do
  isos = Rake::FileList["#{ISO_DIR}/reactos-bootcd*"]
  isos.sort!
  isos.pop
  rm isos
end

desc "Download zipped ISO"
task :download_iso, [:build] do |task, build|
  case build
  when %r{rc$}
    url = fetch_rc_url
    download_file(url, ISO_DIR)
  when %r{nightly$}
    url = fetch_nightly_url(TARGET)
    download_file(url, ISO_DIR)
  end
  Rake::Task[:extract_iso].execute
end

desc "Download virtio ISO"
task :download_virtio_iso do
  # disabled for now
  # download_file(VIRTIO_ISO_URL, ISO_DIR)
end

desc "Download gecko engine"
task :download_gecko => :download_virtio_iso do
  # disabled for the time being
  # still working out some issues
  # download_file(WINE_GECKO_URL)
end

desc "extract iso from archive"
task :extract_iso do
  cd ISO_DIR do
    Rake::FileList['*.7z', '*.zip'].each do |archive|
      sh %(7z x -y "#{archive}" )
      sh %(rm #{archive})
    end
  end
end

desc "Build OS images"
task :build => [ISO_DIR, LOG_DIR, :download_gecko] do
  Rake::FileList['*.pkrvars.hcl'].each do |hcl|
    name = hcl.pathmap('%n').pathmap('%n')
    write_config(hcl)
    environment(name)
    next unless hcl =~ BUILD
    Rake::Task[:download_iso].execute(name)
    file_glob = iso_glob(hcl, TARGET)
    iso_file  = iso_path(file_glob)
    modify_iso(iso_file)
    sh %(packer build ) +
       %(-parallel-builds=1 ) +
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
