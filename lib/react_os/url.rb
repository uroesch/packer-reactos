module ReactOS
  class URL
    require 'yaml'

    CONFIG_YAML = 'config.yaml'

    # determine the latest nightly release URL
    def self.nightly_url(target = 'x86')
      fetch_url('nightly').each do |line|
        next unless line =~ %r{reactos-bootcd-.*\.7z}
        next unless line =~ %r{-#{target}-}
        return config['nightly']['url'] +
          line.gsub(%r{.*href=["'](.*?)["'].*}xs, '\1').strip
      end
    end

    # determine the latest RC release URL
    def self.rc_url
      fetch_url('rc').each do |line|
        next unless line =~ %r{href=.*-RC-.*-iso\.zip}
        return line.gsub(%r{.*href=["'](.*?)["'].*}xs, '\1').strip
      end
    end

    # return the basename and iso file name of a url
    # file taking into account the whacky sourceforge.net url.
    def self.basename(url)
      # remove the '/download' from the sf url
      basename = File.basename(url.sub(%r{/download$}, ''))
      # determine the name after extraction from zip
      iso_name = basename.ext.sub(%r{-iso$}, '') + '.iso'
      return basename, iso_name
    end

    private
    def self.config
      return @config if @config
      begin
        @config = YAML.load_file(CONFIG_YAML)
      rescue => e
        $stderr.puts e.message
        exit 1
      end
    end

    def self.fetch_url(name)
      data   = config[name]
      result = URI.open(data['url'])
      lines  = result.readlines
      data.fetch('top_down', true) ? lines : lines.reverse
    end
  end
end
