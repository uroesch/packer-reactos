module ReactOS
  require 'ostruct'

  class Config < OpenStruct
    require 'yaml'

    CONFIG_YAML = 'config.yaml'

    def initialize(**kwargs)
      @build     = kwargs.fetch(:build, 'nightly')
      @arch      = kwargs.fetch(:arch, 'x86')
      @yaml_file = kwargs.fetch(:yaml_file, CONFIG_YAML)
      begin
        super(config)
      rescue => e
        $stderr.puts e.message
        exit 1
      end
    end

    private
    def parse_yaml
      p @yaml = YAML.load_file(@yaml_file)
    end

    def config
      parse_yaml
      p @build
      @config = @yaml.fetch(@build, {})
      @config.store(:build, @build)
      @config.store(:arch, @arch)
      @config = Hash[@config.map { |k,v| [k.to_sym, v] }]
      process_iso_patterns
      @config
    end

    def process_iso_patterns
      @config[:iso_patterns].map! { |x| Regexp.new(x % @config) }
      @config[:iso_patterns] = Regexp.union(@config[:iso_patterns])
    end
  end
end
