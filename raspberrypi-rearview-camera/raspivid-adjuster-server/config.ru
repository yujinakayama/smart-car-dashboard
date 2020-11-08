# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'raspivid_adjuster_server'
run RaspividAdjusterServer
