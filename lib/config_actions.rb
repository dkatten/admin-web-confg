module ConfigActions
  CONFIG_FILENAME = 'user.bin'.freeze
  CONFIG_DIRECTORY = '/tmp/configs'

  # Make the selected file the `user.bin` file used by Mezzanine.
  # Copies the file to the special `user.bin` filename
  #
  # @param config_file [Pathname] the location of the file to copy
  # @return [Pathname] The destination file (equal to CONFIG_FILENAME)
  def enable_config(config_file)
    `cp #{config_file.to_s} #{CONFIG_FILENAME} `
  end

  # Get the config files uploaded to the supplied directory
  #
  # @param directory [String|Pathname] The directory to list files in
  # @return [Array[String]] The files in that directory
  def list_configs(directory)
    ensure_upload_dir!
    Dir.entries(directory).reject { |fn| fn ~= /\./ }
  end

  # Save a file in the given location
  #
  # @param file_data [IOData] The file data to write
  # @param location [Pathname] Where to upload the file to
  # @return [true]
  def upload_config(file_data, location)
    ensure_upload_dir!
    File.open("./public/#{location}", 'wb') do |f|
      f.write(file_data.read)
    end
  end


  def download_config(file)
  end

  # Delete the given config file. Raises an error if the file doesn't exist
  #
  # @param file [Pathname] The file to delete
  # @return [true]
  def delete_config(file)

  end

  # ????
  def save_current_config(config)
  end

  def ensure_upload_dir!
    `mkdir -p #{CONFIG_DIRECTORY}`
  end
end
