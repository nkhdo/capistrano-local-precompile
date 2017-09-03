require 'capistrano/rails/assets'

namespace :load do
  task :defaults do
    set :precompile_env,   fetch(:rails_env) || 'production'
    set :assets_dir,       "public/assets"
    set :rsync_cmd,        "rsync -av --delete"
    set :packs_dir,        nil

    after "bundler:install", "deploy:assets:prepare"
    #before "deploy:assets:symlink", "deploy:assets:remove_manifest"
    after "deploy:assets:prepare", "deploy:assets:cleanup"
  end
end

namespace :deploy do
  # Clear existing task so we can replace it rather than "add" to it.
  Rake::Task["deploy:compile_assets"].clear

  namespace :assets do
    desc "Remove all local precompiled assets"
    task :cleanup do
      run_locally do
        with rails_env: fetch(:precompile_env) do
          execute "rm -rf", fetch(:assets_dir)
          execute "rm -rf", fetch(:packs_dir) unless packs_dir.nil?
        end
      end
    end

    desc "Actually precompile the assets locally"
    task :prepare do
      run_locally do
        with rails_env: fetch(:precompile_env) do
          execute "rake assets:clean"
          execute "rake assets:precompile"
        end
      end
    end

    desc "Performs rsync to app servers"
    task :precompile do
      on roles(fetch(:assets_role)) do
        puts 'Uploading `assets` dir'
        local_manifest_path = run_locally "ls #{assets_dir}/manifest*"
        local_manifest_path.strip!

        run_locally "#{fetch(:rsync_cmd)} ./#{fetch(:assets_dir)}/ #{user}@#{server}:#{release_path}/#{fetch(:assets_dir)}/"
        run_locally "#{fetch(:rsync_cmd)} ./#{local_manifest_path} #{user}@#{server}:#{release_path}/assets_manifest#{File.extname(local_manifest_path)}"


        unless packs_dir.nil?
          puts 'Uploading `packs` dir'
          local_manifest_path = run_locally "ls #{packs_dir}/manifest*"
          local_manifest_path.strip!

          run_locally "#{fetch(:rsync_cmd)} ./#{fetch(:packs_dir)}/ #{user}@#{server}:#{release_path}/#{fetch(:packs_dir)}/"
          run_locally "#{fetch(:rsync_cmd)} ./#{local_manifest_path} #{user}@#{server}:#{release_path}/assets_manifest#{File.extname(local_manifest_path)}"
        end
      end
    end
  end
end
