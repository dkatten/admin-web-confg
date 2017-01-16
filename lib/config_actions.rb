module ConfigActions
  @@filename = 'user.bin' # This should be changed by the #set_magic_activation_file method

  # Make the selected file the `user.bin` file used by Mezzanine.
  # Copies the file to the special `user.bin` filename
  #
  # @param config_file [Pathname] the location of the file to copy
  # @return [Pathname] The destination file (equal to CONFIG_FILENAME)
  def enable_config(config_file)
    `cp -f #{config_file.to_s} #{@@filename} `
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
    # TODO
  end

  # ????
  def save_current_config(config)
    # TODO
  end

  def ensure_upload_dir!(dir)
    `mkdir -p #{dir}` unless File.directory? dir
  end

  def set_magic_activation_file(filename)
    @@filename = filename
  end
end
