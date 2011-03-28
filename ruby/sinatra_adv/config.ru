#!/usr/bin/env rackup
require "rubygems"
require "bundler"
Bundler.setup

require 'sinatra/base'
require "active_support/json"
require "curb"
require "example"

run Example
