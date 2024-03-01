# Plugin Name: Reawote PBR Loader

require 'sketchup.rb'
require 'extensions.rb'

module Reawote
  module ReawotePBRLoader
    PLUGIN_ID = File.basename(__FILE__, '.rb')
    PLUGIN_DIR = File.join(File.dirname(__FILE__), PLUGIN_ID)

    EXTENSION = SketchupExtension.new(
      'Reawote PBR Loader',
      File.join(PLUGIN_DIR, 'main')
    )
    EXTENSION.creator = 'Reawote'
    EXTENSION.description = 'Importing PBR materials from Reawote library.'
    EXTENSION.version = '1.0.0'
    EXTENSION.copyright = "Real World Textures s.r.o. 2024"
    Sketchup.register_extension(EXTENSION, true)
  end
end
