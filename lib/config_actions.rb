module ConfigActions
  @@magic_filename = 'user.bin' # This should be changed by the #set_magic_activation_file method
  @@active = '.active'
  # Make the selected file the `user.bin` file used by Mezzanine.
  # Copies the file to the special `user.bin` filename
  #
  # @param config_file [Pathname] the location of the file to copy
  # @return [Pathname] The destination file (equal to CONFIG_FILENAME)
  def enable_config(config_file)
    `cp -f #{config_file.to_s} #{@@magic_filename} `
  end

  # Get the config files uploaded to the supplied directory
  #
  # @param directory [String|Pathname] The directory to list files in
  # @return [Array[String]] The files in that directory
  def list_configs(directory)
    Dir.entries(directory).reject { |fn| fn =~ /^\./ }
  end
  module_function :list_configs

  # Delete the given config file. Raises an error if the file doesn't exist
  #
  # @param file [Pathname] The file to delete
  # @return [true]
  def delete_config(file)
    if File.exists? file
      `rm -f #{file}`
    end
  end
  module_function :delete_config

  # Saves the current magic file with the given name
  def save_current_config(as_filename)
    `cp -f #{@@magic_filename} #{as_filename}`
  end
  module_function :save_current_config

  def activate_profile(filename)
    if Pathname.new(filename).exist?
      ConfigActions::set_active_config(filename)
      `cp -f #{filename} #{@@magic_filename}`
    else
      raise "NOPE"
    end
  end
  module_function :activate_profile

  def ensure_upload_dir!(dir)
    `mkdir -p #{dir}` unless File.directory? dir
  end
  module_function :ensure_upload_dir!

  def set_magic_filename(filename)
    @@magic_filename = filename
  end
  module_function :set_magic_filename

  def set_active_filename(filename)
    @@active = filename
  end
  module_function :set_active_filename

  def set_active_config(config_filename)
    File.open(@@active, 'w') {|f| f.write(config_filename) }
  end
  module_function :set_active_config

  def magic_file
    @@magic_filename
  end

  def active_file
    @@active
  end

  def current_active_config
    File.read(@@active).strip
  end

  def able_to_activate_profile?
  end

  def able_to_save_file?(proposed_name, directory)
    !Dir.entries(directory).any? {|fn| fn == proposed_name}
  end

  def able_to_upload_file?(proposed_name, directory)
    able_to_save_file?
  end

  def space_on_device?
  end
end
