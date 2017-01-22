require 'pp'
require 'set'
require 'cgi'
require 'json'
require 'fileutils'
require_relative '../../lib/config_actions'

module Config
  module ConfigDetails
    module_dir = File.dirname(__FILE__)
    public_dir = File.join(module_dir, 'public')
    template_dir = File.join(module_dir, 'views')

    include gen_submodule_public(public_dir, '/config/config_details')
    include gen_submodule_render(template_dir)

    # CONFIG_FILE = '/var/ob/calibration_directory_and_file.txt'
    CONFIG_FILE = '/Users/dkatten/code/admin-web-config/location.txt'

    magic_file = File.read(CONFIG_FILE).strip
    ConfigActions::set_magic_filename(magic_file)

    # CALIBRATION_DIRECTORY = Pathname.new('/var/ob/configs')
    CALIBRATION_DIRECTORY = Pathname.new('/Users/dkatten/code/configs')
    ConfigActions::set_active_filename(CALIBRATION_DIRECTORY.join('.active'))

    def self.registered(app)

      app.helpers do
        def file_exists?(filename)
          File.exist? filename
        end
        def file_is_active?(filename)
          File.basename(ConfigActions::current_active_config || "") == filename
        end
      end

      ConfigActions::ensure_upload_dir!(CALIBRATION_DIRECTORY)

      app.get '/configs' do
        active_file = File.basename(ConfigActions::current_active_config || "")
        error = params[:e]
        ConfigDetails::render(method(:erb), 'config.erb', {
          configs: ConfigActions::list_configs(CALIBRATION_DIRECTORY) || [],
          active: active_file,
          msg: error
        })
      end

      app.post '/configs/activate/:filename' do
        fn = params[:filename].gsub('..', '')
        full_filename = CALIBRATION_DIRECTORY.join(fn)
        if file_exists? full_filename
          ConfigActions::activate_profile(full_filename)
          redirect '/configs'
        else
          redirect '/configs?e=Unable to enable profile'
        end
      end

      app.post '/configs/delete/:filename' do
        fn = params[:filename].gsub('..', '')
        en = (params[:enable] || '').gsub('..', '')
        full_filename = CALIBRATION_DIRECTORY.join(fn)
        if file_exists? full_filename
          if file_is_active?(fn) && params[:enable] && file_exists?(CALIBRATION_DIRECTORY.join(en))
             ConfigActions::activate_profile(CALIBRATION_DIRECTORY.join(en))
          end
          ConfigActions::delete_config(full_filename)
          redirect '/configs'
        else
          redirect '/configs?e=Unable to delete profile'
        end
      end

      app.post '/configs/save_as_active' do
        filename = params['filename'].gsub(/\s/, '-').gsub('.', '-')
        if !file_exists? CALIBRATION_DIRECTORY.join(filename)
          ConfigActions::save_current_config(CALIBRATION_DIRECTORY.join(filename))
          redirect '/configs'
        else
          redirect '/configs?e=Unable to save profile with that name as it already exists'
        end
      end

      app.post '/configs/upload' do
        filename = params['filename'].gsub(/\s/, '-').gsub('.', '-')
        tempfile = params['file'][:tempfile]
        File.copy(tempfile.path, CALIBRATION_DIRECTORY.join(filename))
        redirect '/configs'
      end

      app.get '/configs/download/:filename' do
        fn = params[:filename].gsub('..', '')
        full_filename = CALIBRATION_DIRECTORY.join(fn)
        if File.exists?(full_filename)
          send_file full_filename, :filename => fn, :type => 'Application/octet-stream'
        else
          ConfigDetails::render(method(:erb), 'config.erb', {
            configs: ConfigActions::list_configs(CALIBRATION_DIRECTORY),
            error: "Unable to find config"
          })
        end
      end
    end
  end
end
