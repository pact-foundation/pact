module Pact
  module Provider
    class PactURI
      attr_reader :uri, :options, :metadata

      def initialize (uri, options = nil, metadata = nil)
        @uri = uri
        @options = options || {}
        @metadata = metadata || {} # make sure it's not nil if nil is passed in
      end

      def == other
        other.is_a?(PactURI) &&
          uri == other.uri &&
          options == other.options &&
          metadata == other.metadata
      end

      def basic_auth?
        !!username
      end

      def username
        options[:username]
      end

      def password
        options[:password]
      end

      def to_s
        uri_string = uri.to_s
        if basic_auth? && uri_string.start_with?('http://', 'https://')
          URI(uri_string).tap { |x| x.userinfo="#{username}:*****"}.to_s
        else
          uri_string
        end
      end
    end
  end
end
