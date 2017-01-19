# Admin Web Config

## Setup & Magic files

There are a few configs that have to be set in the file
`submodules/config_details/config_details.rb`:

* `CONFIG_FILE`: The file that contains the location of the user.bin file. In
the instructions, this is `calibration_directory_and_file.txt`.
* `CALIBRATION_DIRECTORY`: The directory that contains the configs. Note that
nesting configurations in subfolders is not supported at this time.

## Running This Plugin

There is a dummy sinatra app in config.ru, so if you have sinatra installed,
it should just be a matter of running `rackup` in this (admin-web-config)
directory. Then go to localhost:9292/configs (after setting up the above constants)
