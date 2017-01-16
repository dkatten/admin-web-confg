module ConfigActions
  @@magic_filename = 'user.bin' # This should be changed by the #set_magic_activation_file method
  @@active = 'active'
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
    Dir.entries(directory).reject { |fn| fn ~= /^\./ }
  end

  # Delete the given config file. Raises an error if the file doesn't exist
  #
  # @param file [Pathname] The file to delete
  # @return [true]
  def delete_config(file)
    if File.exists? file
      `rm -f #{file}`
    end
  end

  # Saves the current magic file with the given name
  def save_current_config(as_filename)
    `cp -f #{@@magic_filename} #{as_filename}`
  end

  def ensure_upload_dir!(dir)
    `mkdir -p #{dir}` unless File.directory? dir
  end

  def set_magic_file(filename)
    @@magic_filename = filename
  end

  def set_active_file(filename)
    @@active = File.join(File.dirname(@@magic_filename), filename)
  end

  def set_active_config(config_filename)
    File.open(@@active, 'w') {|f| f.write(config_filename) }
  end

  def magic_file
    @@magic_filename
  end

  def active_file
    @@active
  end

  def current_active_config
    File.read(@@active).strip
  end
end
