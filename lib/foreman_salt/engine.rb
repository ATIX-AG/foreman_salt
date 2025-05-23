require 'deface'
require 'foreman_remote_execution'

module ForemanSalt
  class Engine < ::Rails::Engine
    engine_name 'foreman_salt'

    config.autoload_paths += Dir["#{config.root}/app/lib"]

    config.paths['config/routes.rb'].unshift('config/api_routes.rb')

    initializer 'foreman_salt.require_dynflow', before: 'foreman_tasks.initialize_dynflow' do
      ForemanTasks.dynflow.require!
    end

    initializer 'foreman_salt.load_app_instance_data' do |app|
      ForemanSalt::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end
    end

    initializer 'foreman_salt.assets.precompile' do |app|
      app.config.assets.precompile += %w[foreman_salt/states.js]
      app.config.assets.precompile += %w[foreman_salt/Salt.png]
    end

    initializer 'foreman_salt.configure_assets', group: :assets do
      SETTINGS[:foreman_salt] = {
        assets: {
          precompile: ['foreman_salt/Salt.png',
                       'foreman_salt/states.js'],
        },
      }
    end

    initializer 'foreman_salt.apipie' do
      Apipie.configuration.checksum_path += ['/salt/api/']
    end

    initializer 'foreman_salt.register_plugin', before: :finisher_hook do |app|
      app.reloader.to_prepare do
        require_relative 'plugin'
      end
    end

    config.to_prepare do
      require_relative 'extensions'

      RemoteExecutionProvider.register(:Salt, SaltProvider)
      ForemanSalt.register_rex_feature
    end
  end

  # check whether foreman_remote_execution to integrate is available in the system
  def self.with_remote_execution?
    RemoteExecutionFeature
  rescue StandardError
    false
  end

  def self.register_rex_feature
    options = {
      description: N_('Run Salt state.highstate'),
      host_action_button: true,
    }

    RemoteExecutionFeature.register(:foreman_salt_run_state_highstate, N_('Run Salt'), options)
  end
end
