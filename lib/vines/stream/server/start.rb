# encoding: UTF-8

module Vines
  class Stream
    class Server
      class Start < State
        def initialize(stream, success=AuthMethod)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless stream?(node)
          # TODO we need a s2s_enable_encription config parameter
          s2s_enable_encryption = false
          # TODO end
          stream.start(node)
          doc = Document.new
          features = doc.create_element('stream:features') do |el|
            el << doc.create_element('starttls') do |tls|
              tls.default_namespace = NAMESPACES[:tls]
              tls << doc.create_element('required') if s2s_enable_encryption
            end
            el << doc.create_element('dialback') do |db|
              db.default_namespace = NAMESPACES[:dialback]
            end
          end
          stream.write(features)
          advance
        end
      end
    end
  end
end
