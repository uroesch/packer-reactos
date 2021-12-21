module ReactOS
  class ISO
    require 'find'
    require 'shellwords'

    # find and return the iso file based on pattern
    def self.path(pattern)
      p pattern
      @iso_path = Find.find('.').find { |f| File.file?(f) && f =~ pattern }
    end

    # modify the ISO file for unattended installation via file injection.
    def self.modify(iso_path)
      @iso_path = iso_path
      # preparation for injecting wine_gecko
      # extract_file('/reactos/reactos.cab', 'reactos.cab')
      inject_file('unattend.inf', '/reactos/unattend.inf')
    end

    # extract a particular file from the ISO
    def self.extract_file(iso_file, local_file)
      cmd = %(xorriso )
        %(-osirrox on )
        %(-indev "#{@iso_path}" )
        %(-extract "#{iso_file}" "#{local_file}")
      run(cmd)
    end

    # inject a modified file into the ISO / may overwrite existing file.
    def self.inject_file(local_file, iso_file)
      cmd = %(xorriso ) +
        %(-overwrite on ) +
        %(-dev "#{@iso_path}" ) +
        %(-boot_image any replay ) +
        %(-map_single "#{local_file}" "#{iso_file}")
      run(cmd)
    end

    private

    def self.run(cmd)
      cmd = Shellwords.split(cmd) if cmd.class === String
      exit unless system(*cmd)
    end
  end
end
