# Mixin to enable symmetric encryption/decryption for e.g. resque options
module RailsPipeline
  module SymmetricEncryptor

    def self.included(base)
      base.extend ClassMethods
      # Inject a class variable
      class << base
        @@secret = nil
      end
      #base.send :include, InstanceMethods
    end

    module ClassMethods

      def symmetric_encrypt(options)
        # Inititalize a symmetric cipher for encryption
        cipher = OpenSSL::Cipher::AES256.new(:CBC)
        cipher.encrypt

        # Create a random salt
        salt = OpenSSL::Random.random_bytes(16)

        # Create a PKCS5 key from the rails password
        # NOTE: suggested way of doing this is by cipher.random_key
        # and then we would store the key on the user.
        key = _key(_secret, salt)

        # Set the key and get a random initialization vector
        cipher.key = key
        iv = cipher.random_iv

        # Do the encryption
        encrypted = cipher.update(options.to_json) + cipher.final
        return {
          "user_id" => options["user_id"],
          "encrypted" => Base64.encode64(encrypted),
          "iv" => Base64.encode64(iv),
          "salt" => Base64.encode64(salt),
        }
      end

      def symmetric_decrypt(enc_options)
        salt = Base64.decode64(enc_options["salt"])
        key = _key(_secret, salt)
        cipher = OpenSSL::Cipher::AES256.new(:CBC)
        # Initialize for decryption
        cipher.decrypt

        # Set up key and iv
        cipher.key = key
        cipher.iv = Base64.decode64(enc_options["iv"])

        # Decrypt
        decoded = Base64.decode64(enc_options["encrypted"])
        options = cipher.update(decoded) + cipher.final

        return JSON.parse(options)
      end

      def _secret
        Rails.application.config.secret_token
      end

      def _key(secret, salt)
        iter = 20000
        key_len = 32
        key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(secret, salt, iter, key_len)
        return key
      end

    end
  end
end
