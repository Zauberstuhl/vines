# encoding: UTF-8

module Vines
  class Stream
    # Implements the XMPP protocol for server-to-server (s2s) streams. This
    # serves connected streams using the jabber:server namespace. This handles
    # both accepting incoming s2s streams and initiating outbound s2s streams
    # to other servers.
    class Server < Stream
      MECHANISMS = %w[EXTERNAL].freeze

      # Starts the connection to the remote server. When the stream is
      # connected and ready to send stanzas it will yield to the callback
      # block. The callback is run on the EventMachine reactor thread. The
      # yielded stream will be nil if the remote connection failed. We need to
      # use a background thread to avoid blocking the server on DNS SRV
      # lookups.
      def self.start(config, to, from, dbv = false, &callback)
        op = proc do
          Resolv::DNS.open do |dns|
            dns.getresources("_xmpp-server._tcp.#{to}", Resolv::DNS::Resource::IN::SRV)
          end.sort! {|a,b| a.priority == b.priority ? b.weight <=> a.weight : a.priority <=> b.priority }
        end
        cb = proc do |srv|
          if srv.empty?
            srv << {target: to, port: 5269}
            class << srv.first
              def method_missing(name); self[name]; end
            end
          end
          Server.connect(config, to, from, srv, dbv, callback)
        end
        EM.defer(proc { op.call rescue [] }, cb)
      end

      def self.connect(config, to, from, srv, dbv = false, callback)
        if srv.empty?
          # fiber so storage calls work properly
          Fiber.new { callback.call(nil) }.resume
        else
          begin
            rr = srv.shift
            opts = {to: to, from: from, srv: srv, dialback_verify: dbv, callback: callback}
            EM.connect(rr.target.to_s, rr.port, Server, config, opts)
          rescue => e
            connect(config, to, from, srv, dbv, callback)
          end
        end
      end

      attr_reader   :domain
      attr_accessor :remote_domain

      def initialize(config, options={})
        super(config)
        @outbound_tls_required = false
        @peer_trusted = nil
        @connected = false
        @remote_domain = options[:to]
        @domain = options[:from]
        @srv = options[:srv]
        @dialback_verify = options[:dialback_verify]
        @callback = options[:callback]
        @outbound = @remote_domain && @domain
        start = @outbound ? Outbound::Start.new(self) : Start.new(self)
        advance(start)
      end

      def post_init
        super
        send_stream_header if @outbound
      end

      def max_stanza_size
        config[:server].max_stanza_size
      end

      def ssl_verify_peer(pem)
        @store.trusted?(pem).tap {|trusted| @peer_trusted = trusted}
        true
      end

      def ssl_handshake_completed
        @peer_trusted = cert_domain_matches?(@remote_domain) && @peer_trusted
      end

      def dialback_retry?
        !@peer_trusted.nil? && !@peer_trusted
      end

      def outbound_tls_required?
        @outbound_tls_required
      end

      def outbound_tls_required(required)
        if !!required == required
          @outbound_tls_required = required
        end
      end

      # Return an array of allowed authentication mechanisms advertised as
      # server stream features.
      def authentication_mechanisms
        MECHANISMS
      end

      def stream_type
        :server
      end

      def unbind
        super
        if @outbound && !@connected
          Server.connect(config, @remote_domain, @domain, @srv, @callback)
        end
      end

      def vhost?(domain)
        config.vhost?(domain)
      end

      def notify_connected
        @connected = true
        self.callback!
        @callback = nil
      end

      def callback!
        @callback.call(self) if @callback
      end

      def dialback_verify?
        @dialback_verify
      end

      def ready?
        state.class == Server::Ready
      end

      def start(node)
        if @outbound then send_stream_header; return end
        to, from = %w[to from].map {|a| node[a] }
        @domain, @remote_domain = to, from unless @domain
        send_stream_header
        raise StreamErrors::NotAuthorized if domain_change?(to, from)
        raise StreamErrors::UnsupportedVersion unless node['version'] == '1.0'
        raise StreamErrors::ImproperAddressing unless valid_address?(@domain) && valid_address?(@remote_domain)
        raise StreamErrors::HostUnknown unless config.vhost?(@domain) || config.pubsub?(@domain) || config.component?(@domain)
        raise StreamErrors::NotAuthorized unless config.s2s?(@remote_domain) && config.allowed?(@domain, @remote_domain)
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns'] == NAMESPACES[:server]
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns:stream'] == NAMESPACES[:stream]
      end

      private

      # The `to` and `from` domain addresses set on the initial stream header
      # must not change during stream restarts. This prevents a server from
      # authenticating as one domain, then sending stanzas from users in a
      # different domain.
      #
      # to   - The String domain the other server thinks we are.
      # from - The String domain the other server is asserting as its identity.
      #
      # Returns true if the other server is misbehaving and its connection
      #   should be closed.
      def domain_change?(to, from)
        to != @domain || from != @remote_domain
      end

      def send_stream_header
        stream_id = Kit.uuid
        update_stream_id(stream_id)
        attrs = {
          'xmlns'        => NAMESPACES[:server],
          'xmlns:stream' => NAMESPACES[:stream],
          'xmlns:db'     => NAMESPACES[:legacy_dialback],
          'xml:lang'     => 'en',
          'id'           => stream_id,
          'from'         => @domain,
          'to'           => @remote_domain,
        }
        attrs['version'] = '1.0' unless dialback_verify?
        write "<stream:stream %s>" % attrs.to_a.map{|k,v| "#{k}='#{v}'"}.join(' ')
      end
    end
  end
end
