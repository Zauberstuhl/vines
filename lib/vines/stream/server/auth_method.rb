# encoding: UTF-8

module Vines
  class Stream
    class Server
      class AuthMethod < State
        STARTTLS, RESULT, FROM, TO = %w[starttls db:result from to].map {|s| s.freeze }
        PROCEED  = %Q{<proceed xmlns="#{NAMESPACES[:tls]}"/>}.freeze
        FAILURE  = %Q{<failure xmlns="#{NAMESPACES[:tls]}"/>}.freeze

        def initialize(stream, success=AuthRestart)
          super
        end

        def node(node)
          if starttls?(node)
            if stream.encrypt?
              stream.write(PROCEED)
              stream.encrypt
              stream.reset
              advance
            else
              stream.write(FAILURE)
              stream.write('</stream:stream>')
              stream.close_connection_after_writing
            end
          elsif dialback?(node)
            begin
              Vines::Stream::Server.start(stream.config, node[FROM], node[TO], dbv = true) do |authoritative|
                if authoritative
                  authoritative.write("<db:verify from='#{node[TO]}' id='#{stream.id}' to='#{node[FROM]}'>#{node.text}</db:verify>")
                else
                  raise StreamErrors::RemoteConnectionFailed
                end
              end
              # We need to be discoverable for the dialback connection
              stream.router << stream
            rescue StreamErrors::RemoteConnectionFailed => e
              stream.write("<db:result from='#{node[TO]}' to='#{node[FROM]}'" +
                           " type='error'><error type='cancel'><item-not-found " +
                           "xmlns='#{NAMESPACES[:stanzas]}'/></error></db:result>")
              stream.close_connection_after_writing
            end
          else
            raise StreamErrors::NotAuthorized
          end
        end

        private

        def starttls?(node)
          node.name == STARTTLS && namespace(node) == NAMESPACES[:tls]
        end

        def dialback?(node)
          node.name == RESULT && !node.text.empty?
        end
      end
    end
  end
end
