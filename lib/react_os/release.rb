module ReactOS
  class Release

    attr_reader :major, :minor, :patch, :roling, :type, :commit, :arch

    def self.from(path)
      self.new(path).version
    end

    def initialize(path)
      @path    = path
      @major   = nil
      @minor   = nil
      @patch   = nil
      @commit  = nil
      @rolling = nil
      @arch    = nil
    end


    def version
      parser
      [ 'ReactOS', @version, @type, @rolling, @commit, @arch ]
        .delete_if(&:empty?)
        .join('-')
    end

    private

    def parser
      @tokens ||= basename.split('-')[1..]
      @tokens.delete_if { |x| x == 'bootcd' }
      @major, @minor, @patch = @tokens[0].split('.')
      @version = @tokens.first
      @type    = @tokens.fetch(1, '').downcase
      @rolling = @tokens.fetch(2, '')
      @commit  = @tokens.fetch(3, '')
      @arch    = @tokens.fetch(4, 'x86')
    end

    def basename
      @basename ||= File.basename(@path, File.extname(@path))
    end
  end
end
