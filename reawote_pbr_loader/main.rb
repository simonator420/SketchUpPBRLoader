module Reawote
  module ReawotePBRLoader

    @@initial_selection = []
    @@percentage = 1.0
    @@dialog = nil

    def self.create_dialog
      options = {
        dialog_title: 'Reawote PBR Loader',
        preferences_key: 'com.example.ReawotePBRLoader',
        style: UI::HtmlDialog::STYLE_DIALOG,
        height: 750,
        width: 430
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_size(options[:width], options[:height])
      dialog.set_file(File.join(__dir__, 'dialog.html'))
      dialog.center

      dialog
    end

    def self.browse_folder
      selected_folder = UI.select_directory(title: "Select a Folder")
      if selected_folder
        @@dialog.execute_script("updateFolderPath('#{selected_folder}')")
      end
    end

    def self.list_subfolders(path)
      subfolders = Dir.entries(path).select { |entry| 
        File.directory?(File.join(path, entry)) && !(entry =='.' || entry == '..') 
      }
      @@dialog.execute_script("populateSubfolderList(#{subfolders.to_json})")
    end

    def self.add_callbacks
      @@dialog.add_action_callback("browseFolder") { |action_context|
        browse_folder
      }

      @@dialog.add_action_callback("listSubfolders") { |action_context, path|
        list_subfolders(path)
      }
    end

    def self.display_dialog
      @@dialog = create_dialog
      add_callbacks
      @@dialog.show if @@dialog
    end

    unless(file_loaded?(__FILE__))
      file_loaded(__FILE__)
      menu = UI.menu('Plugins')
      menu.add_item('Reawote PBR Loader') { display_dialog }
    end
  end
end
