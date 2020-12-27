# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'raspivid_options'

class RaspividAdjusterServer < Sinatra::Application
  SCRIPT_PATH = ENV['RASPIVID_SCRIPT_PATH'] || '/opt/bin/raspivid-server'

  put '/raspivid-options' do
    json = request.body.read

    raspivid_options = RaspividOptions.new(JSON.parse(json))
    script = generate_script(raspivid_options)

    if !File.exist?(SCRIPT_PATH) || File.read(SCRIPT_PATH) != script
      File.write(SCRIPT_PATH, script)
    end

    status 204
  end

  def generate_script(raspivid_options)
    default_args = %w[--nopreview --output tcp://0.0.0.0:5001 --listen --timeout 0 --flush]
    all_args = default_args + raspivid_options.to_cli_args

    <<~END
      #!/bin/sh

      raspivid #{all_args.join(' ')}
    END
  end

  disable :show_exceptions

  error RaspividOptions::Error do
    error = env['sinatra.error']
    status 400
    body error.message
  end

  error do
    status 500
  end
end
