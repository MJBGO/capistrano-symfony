load File.expand_path("../set_symfony_env.rake", __FILE__)

def symfony_console(release_path, command, params = '')
  execute :php, release_path.join(fetch(:symfony_console_path)), command, params, fetch(:symfony_console_flags)
end

def build_bootstrap_path
  bootstrap_path = symfony_vendor_path.join("sensio/distribution-bundle")

  if fetch(:sensio_distribution_version).to_i <= 4
    bootstrap_path = bootstrap_path.join("Sensio/Bundle/DistributionBundle")
  end

  bootstrap_path.join("Resources/bin/build_bootstrap.php")
end

namespace :symfony do
  desc "Execute a provided symfony command"
  task :console, :command, :params, :role do |t, args|
    # ask only runs if argument is not provided
    ask(:cmd, "cache:clear")
    command = args[:command] || fetch(:cmd)
    role = args[:role] || :all
    params = args[:params] || ''

    on release_roles(role) do
      within release_path do
        symfony_console(release_path, command, params)
      end
    end

    Rake::Task[t.name].reenable
  end

  namespace :cache do
    desc "Run app/console cache:clear for the #{fetch(:symfony_env)} environment"
    task :clear do
      on release_roles(:all) do
        symfony_console(release_path, "cache:clear")
      end
    end

    desc "Run app/console cache:warmup for the #{fetch(:symfony_env)} environment"
    task :warmup do
      on release_roles(:all) do
        symfony_console(release_path, "cache:warmup")
      end
    end
  end

  namespace :assets do
    desc "Install assets"
    task :install do
      on release_roles(:all) do
        within release_path do
          symfony_console(release_path, "assets:install", fetch(:assets_install_path) + ' ' + fetch(:assets_install_flags))
        end
      end
    end
  end

  desc "Create the cache directory"
  task :create_cache_dir do
    on release_roles :all do
      within release_path do
        if test "[ -d #{release_path.join(fetch(:cache_path))} ]"
          execute :rm, "-rf", release_path.join(fetch(:cache_path))
        end
        execute :mkdir, "-pv", release_path.join(fetch(:cache_path))
      end
    end
  end

  desc "Set user/group permissions on configured paths"
  task :set_permissions do
    on release_roles :all do
      if fetch(:permission_method)
        invoke "deploy:set_permissions:#{fetch(:permission_method).to_s}"
      end
    end
  end

  desc "Clear non production controllers"
  task :clear_controllers do
    next unless any? :controllers_to_clear
    on release_roles :all do
      within release_path.join(fetch(:web_path)) do
        execute :rm, "-f", *fetch(:controllers_to_clear)
      end
    end
  end

  desc "Build the bootstrap file"
  task :build_bootstrap do
    on release_roles :all do
      within release_path do
        if fetch(:symfony_directory_structure) == 2
          execute :php, build_bootstrap_path, fetch(:app_path)
        else
          execute :php, build_bootstrap_path, fetch(:var_path)
        end
      end
    end
  end

end

task :symfony => ["symfony:console"]
