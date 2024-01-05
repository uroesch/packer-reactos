module ReactOS
  class URL
    require 'yaml'

    CONFIG_YAML = 'config.yaml'

    class << self
      # determine the latest nightly release URL
      def nightly_url(target = 'x86')
        url = baseurl(config['nightly']['url'])
        fetch_url('nightly')[1..10].each do |line|
          next unless line =~ %r{reactos-bootcd-.*\.7z}
          next unless line =~ %r{-#{target}-}
          return url + line.gsub(%r{.*href=["'](.*?)["'].*}xs, '\1').strip
        end
      end

      # determine the latest RC release URL
      def rc_url
        fetch_url('rc').each do |line|
          next unless line =~ %r{href=.*-RC-.*-iso\.zip/download}
          return line.gsub(%r{.*href=["'](.*?)["'].*}xs, '\1').strip
        end
      end

      # determine the latest RC release URL
      def release_url
        fetch_url('release').each do |line|
          regex = %r{href=.*(-release-\d+-.*|\d+\.\d+\.\d+)-iso\.zip/download}
          next unless line =~ regex
          return line.gsub(%r{.*href=["'](.*?)["'].*}xs, '\1').strip
        end
      end

      def baseurl(url)
        # remove the query string
        url.split(%r{\?}).first
      end

      # return the basename and iso file name of a url
      # file taking into account the whacky sourceforge.net url.
      def basename(url)
        # remove the '/download' from the sf url
        p basename = File.basename(url.sub(%r{/download$}, ''))
        # determine the name after extraction from zip
        p iso_name = basename.ext.sub(%r{-iso$}, '') + '.iso'
        return basename, iso_name
      end

      private
      def config
        return @config if @config
        begin
          @config = YAML.load_file(CONFIG_YAML)
        rescue => e
          $stderr.puts e.message
          exit 1
        end
      end

      def fetch_url(name)
        data   = config[name]
        result = URI.open(data['url'])
        lines  = result.readlines
        data.fetch('top_down', true) ? lines : lines.reverse
      end
    end
  end
end
