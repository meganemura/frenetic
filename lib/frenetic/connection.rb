require 'delegate'

class Frenetic
  class Connection < SimpleDelegator
    attr_reader :builder_config, :connection_config, :errors

    ConnectionConfigKeys = [:url, :params, :headers, :request, :ssl, :proxy]

    def initialize(config = {})
      @errors = {}
      process_config(config)
      validate_configuration!

      connection = Faraday.new(connection_config) do |builder|
        configure_authentication(builder)
        configure_responder(builder)
        configure_cache(builder)
        configure_adapter(builder)
      end
      super(connection)
    end

    def valid?
      @errors = {}
      @errors[:adapter] = 'must be present' if !@config[:adapter]
      @errors[:url] = 'must be present' if !@config[:url]
      @errors.empty?
    end

    def process_config(raw_cfg)
      @config = {}.merge(raw_cfg.to_hash)
      @config[:url] = Addressable::URI.parse(raw_cfg[:url])
      if @config[:url] && @config[:url].port.nil?
        @config[:url].port = @config[:url].inferred_port
      end
      cfgs = @config.inject({builder:{}, conn:{}}) do |conf, (k,v)|
        if ConnectionConfigKeys.include?(k)
          conf[:conn][k] = v
        else
          conf[:builder][k] = v
        end
        conf
      end
      [
        @builder_config = cfgs[:builder],
        @connection_config = cfgs[:conn]
      ]
    end

    def configure_authentication(builder)
      use_basic_auth(builder) if builder_config[:username]
      use_token_auth(builder) if builder_config[:api_token]
    end

    def configure_responder(builder)
      builder.response(:hal_json)
    end

    def configure_cache(builder)
      case builder_config[:cache]
      when :rack then use_rack_cache(builder)
      when :rails then use_rails_cache(builder)
      end
    end

    def configure_adapter(builder)
      builder.adapter(builder_config[:adapter])
    end

  private

    def validate_configuration!
      raise ConfigError.new(self) if !valid?
    end

    def use_basic_auth(builder)
      builder.request :basic_auth, builder_config[:username], builder_config[:password]
    end

    def use_token_auth(builder)
      builder.request :token_auth, builder_config[:api_token]
    end

    def use_rack_cache(builder)
      require_lib('rack-cache', 'Frenetic Rack::Cache caching strategy')
      builder.use(
        FaradayMiddleware::RackCompatible,
        Rack::Cache::Context,
        {
          metastore:     "file:tmp/rack/meta/#{cache_key}",
          entitystore:   "file:tmp/rack/body/#{cache_key}",
          ignore_headers: %w{Authorization Set-Cookie X-Content-Digest}
        }
      )
    end

    def use_rails_cache(builder)
      require_lib 'faraday-http-cache', 'Frenetic Rails caching strategy'
      builder.use(Faraday::HttpCache, store:Rails.cache, logger:Rails.logger)
    end

    def cache_key
      Digest::MD5.hexdigest connection_config[:url].hostname
    end

    def require_lib(lib = nil, context = nil)
      lib ? require(lib) : yield
    rescue NameError, LoadError => err
      context ||= self
      raise ConfigError, "Could not load required `#{lib}` dependency for #{context}: #{err.message}"
    end
  end
end
