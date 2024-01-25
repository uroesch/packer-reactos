namespace :download do
  desc "Download zipped ISO"
  task :iso, [:build] do |task, build|
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
  task :virtio_iso do
    # disabled for now
    # download_file(VIRTIO_ISO_URL, ISO_DIR)
  end

  desc "Download gecko engine"
  task :gecko => :virtio_iso do
    # disabled for the time being
    # still working out some issues
    # download_file(WINE_GECKO_URL)
  end
end
