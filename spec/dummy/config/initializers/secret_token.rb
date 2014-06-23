# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
Dummy::Application.config.secret_token = ENV['RAILS_SECRET'] || '2b6be71881138496a43ceac5e7cb91ca35455f0e4ceb93ebd695773cec430f4903c7719186b08d2339ed3fd7a8a927d4cb9080c681355116b65286ff832c450e' 
