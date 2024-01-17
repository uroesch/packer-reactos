# -----------------------------------------------------------------------------
# Namespaces
# -----------------------------------------------------------------------------
namespace :clean do
  desc "Clean up everything (disk images, logs, old iso files)"
  task :all => [:images, :logs, :isos]

  desc "Clean all images"
  task :images do
    cd IMAGE_DIR do
      rm Rake::FileList['*.qcow2', '*.tar.gz', '*.vhdx?', '*.vmdk']
    end
  end

  desc "Clean packer logs"
  task :logs do
    cd LOG_DIR do
      rm Rake::FileList['*.log']
    end
  end

  desc "Clean outdated ISO images"
  task :isos do
    cd ISO_DIR do
      %w( reactos-bootcd* *-RC-* ).each do |glob|
        isos = Rake::FileList[glob].sort
        isos.pop
        rm isos unless isos.empty?
      end
    end
  end
end
