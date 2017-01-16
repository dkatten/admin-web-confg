require 'pp'
require 'set'
require 'cgi'
require 'json'
require 'fileutils'

module Config
  module ConfigDetails
    module_dir = File.dirname(__FILE__)
    public_dir = File.join(module_dir, 'public')
    template_dir = File.join(module_dir, 'views')

    include gen_submodule_public(public_dir, '/config/config_details')
    include gen_submodule_render(template_dir)

    CONFIG_PATH = '/var/ob/calibration_directory_and_file.txt'

    magic_file = File.read(CONFIG_PATH).strip
    ConfigActions::set_magic_activation_file(magic_file)

    CONFIG_FILE_LOCATIONS = Pathname.new('/', 'var', 'ob', 'configs')

    def self.registered(app)
      ConfigActions::ensure_upload_dir(CONFIG_FILE_LOCATIONS)

      app.helpers ConfigDetails::Helpers

      app.get '/configs' do
        ConfigDetails::render(method(:erb), 'config.erb'), {
          configs: ConfigActions::list_configs(CONFIG_FILE_LOCATIONS)
        }
      end

      app.post '/configs/activate/:filename' do
        fn = params[:filename].gsub('..', '')
        full_filename = CONFIG_FILE_LOCATIONS.join(fn)
        if File.exists?(full_filename)
          ConfigActions::enable_config(full_filename)
          ConfigDetails::render(method(:erb), 'config.erb') {
            configs: ConfigActions::list_configs(CONFIG_FILE_LOCATIONS),
            success: "Config Activated"
          }
        else
          ConfigDetails::render(method(:erb), 'config.erb') {
            configs: ConfigActions::list_configs(CONFIG_FILE_LOCATIONS),
            error: "Unable to find config"
          }
        end
      end

      app.post '/configs/upload' do
        tempfile = params['file'][:tempfile]
        filename = params['file'][:filename]
        File.copy(tempfile.path, CONFIG_FILE_LOCATIONS.join(filename))
        redirect '/configs'
      end

      app.get 'configs/download/:filename' do
        fn = params[:filename].gsub('..', '')
        full_filename = CONFIG_FILE_LOCATIONS.join(fn)
        if File.exists?(full_filename)
          send_file full_filename, :filename => filename, :type => 'Application/octet-stream'
        else
          ConfigDetails::render(method(:erb), 'config.erb') {
            configs: ConfigActions::list_configs(CONFIG_FILE_LOCATIONS),
            error: "Unable to find config"
          }
        end
      end
    end
  end
end
