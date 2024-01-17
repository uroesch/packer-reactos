# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
$LOAD_PATH.unshift(File.expand_path('lib'))
Rake::FileList['lib/tasks/*.rake'].each { |f| load f }

# -----------------------------------------------------------------------------
# Libraries
# -----------------------------------------------------------------------------
require 'yaml'
require 'json'
require 'erb'
require 'ostruct'
require 'open-uri'
require 'digest'
require 'react_os'

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------
PACKER_HCL_DIR  = 'packer'
BUILD           = ENV.fetch('BUILD', '.*')
ARCH            = ENV.fetch('ARCH', 'x86')
BUILDER         = ENV.fetch('BUILDER', '*')
HEADLESS        = ENV.fetch('HEADLESS', 'true')
PACKER_LOG      = ENV.fetch('PACKER_LOG', 1)
PACKER_LOG_PATH = ENV.fetch('PACKER_LOG_PATH', false)
FAIL_FAST       = ENV.fetch('FAIL_FAST', 'false')
PARALLEL_BUILDS = ENV.fetch('PARALLEL_BUILDS', 1)
LOG_DIR         = 'logs'
ISO_DIR         = 'iso/reactos'
IMAGE_DIR       = 'images'
TEMPLATE_DIR    = 'templates'
WINE_GECKO_URL  = 'https://svn.reactos.org/amine/wine_gecko-2.40-x86.msi'
WINE_GECKO_SHA1 = '8a3adedf3707973d1ed4ac3b2e791486abf814bd'
VIRTIO_ISO_URL  = 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso'

# -----------------------------------------------------------------------------
# Methods
# -----------------------------------------------------------------------------
def packer_version
  ('%d%03d%03d' % `packer version`.gsub(%r{[^\d\.]+}, '').split('.')).to_i
end

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

def packer_auto_var_files
  file_glob = File.join(PACKER_HCL_DIR, '*.auto.pkrvars.hcl')
  Rake::FileList[file_glob]
end

def packer_release_var_files
  file_glob       = File.join(PACKER_HCL_DIR, '*.pkrvars.hcl')
  exclude_pattern = %r{\.auto\.pkrvars\.hcl}
  Rake::FileList[file_glob].exclude(exclude_pattern)
end

def parse_var_files(var_file)
  config = {}
  packer_auto_var_files.each do |auto_var_file|
    config.merge!(parse_var_file(auto_var_file))
  end
  config.merge!(parse_var_file(var_file))
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
  @config = parse_var_files(var_file)
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

# download a file to a directory
def download_file(url, target_dir = '.')
  cd target_dir do
    basename, iso_name = ReactOS::URL.basename(url)
    return if File.exist?(basename) or File.exist?(iso_name)
    puts "Downloading '#{url}' to '#{basename}'"
    IO.copy_stream(URI.open(url), basename)
  end
end

# return the latest version of the ISO file in iso directory
def iso_path(file_glob = '*.iso')
  cd ISO_DIR do
    Dir.glob(file_glob).sort[-1]
  end
end

# create a sha256 sum from the target ISO file
def sha256sum(path)
  'sha256:' << Digest::SHA256.file(path).hexdigest
end

# -----------------------------------------------------------------------------
# Directories
# -----------------------------------------------------------------------------
directory LOG_DIR
directory ISO_DIR
directory IMAGE_DIR

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
      BUILDER=qemu|virtualbox
      ARCH=x86|x64
      PACKER_LOG_PATH=<path>
      HEADLESS=true|false
      PKR_VAR_<packer_variable>=<value>
  HELP
end

desc "Download zipped ISO"
task :download_iso, [:build] do |task, build|
  url = case build
        when %r{release$}
          ReactOS::URL.release_url
        when %r{rc$}
          ReactOS::URL.rc_url
        when %r{nightly$}
          ReactOS::URL.nightly_url(ARCH)
        end
  download_file(url, ISO_DIR)
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

desc "Initialize packer"
task :packer_init do
  if packer_version >= 1009000 
    sh %(packer init #{PACKER_HCL_DIR}) do |ok, res|
      exit res.exitstatus if FAIL_FAST == 'true' && ! ok
    end
  end
end

desc "Build OS images"
task :build => [IMAGE_DIR, ISO_DIR, LOG_DIR, :packer_init] do
  packer_release_var_files.each do |hcl|
    name = hcl.pathmap('%n').pathmap('%n')
    next unless name =~ Regexp.new(BUILD)
    build = name.split('-').last
    write_config(hcl)
    environment(name)
    Rake::Task[:download_iso].execute(name)
    release  = ReactOS::Config.new(build: build, arch: ARCH)
    iso_file = ReactOS::ISO.path(release.iso_patterns)
    ReactOS::ISO.modify(iso_file)
    sh %(packer build ) +
       %(-parallel-builds=#{PARALLEL_BUILDS} ) +
       %(-var-file="#{hcl}" ) +
       %(-var="arch=#{ARCH}" ) +
       %(-var="iso_file=#{iso_file}" ) +
       %(-var="iso_checksum=#{sha256sum(iso_file)}" ) +
       %(-var="headless=#{HEADLESS}" ) +
       %(#{pkr_vars} ) +
       %(-only="#{BUILDER}.#{name}" ) +
       %(#{PACKER_HCL_DIR}) do |ok, res|
         exit res.exitstatus if FAIL_FAST == 'true' && ! ok
       end
  end
end
