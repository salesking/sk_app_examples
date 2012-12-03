#!/usr/bin/env rackup
require 'rubygems'
require 'bundler'
Bundler.setup

require 'sinatra/base'
require 'active_support/json'
require 'active_support/time'
require 'active_support/inflector'
require 'curb'
require 'haml'

require 'sk_sdk'
require 'sk_sdk/signed_request'
require 'sk_sdk/oauth'

require './example'

run Example
