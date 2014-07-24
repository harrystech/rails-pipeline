# Mixin to enable symmetric encryption/decryption for pipeline, using protocol
# buffers on the wire.

require "rails-pipeline/protobuf/encrypted_message.pb"

module RailsPipeline

  module SymmetricEncryptor
    Error = Class.new(StandardError)
    NoApiKeyError = Class.new(Error) do
      def message
        "You need to set the env variable PIPELINE_API_KEY to emit messages"
      end
    end

    class << self
      # Allow configuration via initializer
      @@secret = nil
      def _secret
        @@secret.nil? ? ENV.fetch("PIPELINE_SECRET", Rails.application.config.secret_token) : @@secret
      end

      def secret=(secret)
        @@secret = secret
      end

      @@api_key = nil
      def _api_key
        api_key = @@api_key.nil? ? ENV["PIPELINE_API_KEY"] : @@api_key
        if api_key.blank?
          raise NoApiKeyError.new
        end
        return api_key
      end

      def api_key=(api_key)
        @@api_key = api_key
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      def encrypt(plaintext, owner_info: nil, type_info: nil, topic: nil, event_type: nil)
        # Inititalize a symmetric cipher for encryption
        cipher = OpenSSL::Cipher::AES256.new(:CBC)
        cipher.encrypt

        # Create a random salt
        salt = OpenSSL::Random.random_bytes(16)

        # Create a PKCS5 key from the rails password
        # NOTE: suggested way of doing this is by cipher.random_key
        # and then we would store the key on the user.
        key = _key(salt)

        # Set the key and get a random initialization vector
        cipher.key = key
        iv = cipher.random_iv

        # Do the encryption
        ciphertext = cipher.update(plaintext) + cipher.final
        uuid = SecureRandom.uuid
        return RailsPipeline::EncryptedMessage.new(
          uuid: uuid,
          salt: Base64.encode64(salt),
          iv: Base64.encode64(iv),
          ciphertext: Base64.encode64(ciphertext),
          owner_info: owner_info,
          type_info: type_info,
          topic: topic,
          event_type: _event_type_value(event_type),
          api_key: _api_key,
        )
      end

      # Message is an instance of EncryptedMessage
      def decrypt(message)
        salt = Base64.decode64(message.salt)
        key = _key(salt)
        cipher = OpenSSL::Cipher::AES256.new(:CBC)
        # Initialize for decryption
        cipher.decrypt

        # Set up key and iv
        cipher.key = key
        cipher.iv = Base64.decode64(message.iv)

        # Decrypt
        decoded = Base64.decode64(message.ciphertext)
        plaintext = cipher.update(decoded) + cipher.final

        return plaintext
      end

      def _secret
        RailsPipeline::SymmetricEncryptor._secret
      end

      def _api_key
        RailsPipeline::SymmetricEncryptor._api_key
      end

      def _key(salt)
        iter = 20000
        key_len = 32
        key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(_secret, salt, iter, key_len)
        return key
      end

      def _event_type_value(event_type)
        case event_type
        when :create
          RailsPipeline::EncryptedMessage::EventType::CREATED
        when :update
          RailsPipeline::EncryptedMessage::EventType::UPDATED
        when :destroy
          RailsPipeline::EncryptedMessage::EventType::DELETED
        end
      end

    end
  end
end
