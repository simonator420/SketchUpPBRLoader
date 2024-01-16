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
      @@initial_selection.clear
      selected_folder = UI.select_directory(title: "Select a Folder")
      if selected_folder
        @@initial_selection << selected_folder
        @@dialog.execute_script("updateFolderPath('#{selected_folder}')")
        UI.messagebox("Initial Selection: #{@@initial_selection}")
      end
    end

    def self.browse_new_folder
      selected_folder = UI.select_directory(title: "Select a New Folder to Add to Queue")
      if selected_folder
        @@initial_selection << selected_folder
        # @@dialog.execute_script("addFolderToSubfolderList('#{selected_folder}')")
        UI.messagebox("Initial Selection: #{@@initial_selection}")

        subfolders = Dir.entries(selected_folder).select { |entry| 
          File.directory?(File.join(selected_folder, entry)) && !(entry =='.' || entry == '..') 
        }.sort
      
        formatted_subfolders = subfolders.map do |folder_name|
          parts = folder_name.split("_")
          if parts.count >= 3
            "#{parts[0]}_#{parts[1]}_#{parts[2]}"
          else
            folder_name
          end
        end
      
        @@dialog.execute_script("addFolderToSubfolderList(#{formatted_subfolders.to_json})")

      end
    end

    def self.list_subfolders(path)
      subfolders = Dir.entries(path).select { |entry| 
        File.directory?(File.join(path, entry)) && !(entry =='.' || entry == '..') 
      }.sort
    
      formatted_subfolders = subfolders.map do |folder_name|
        parts = folder_name.split("_")
        if parts.count >= 3
          "#{parts[0]}_#{parts[1]}_#{parts[2]}"
        else
          folder_name
        end
      end
    
      @@dialog.execute_script("populateSubfolderList(#{formatted_subfolders.to_json})")
    end

    def self.refresh_all(path)
      subfolders = Dir.entries(path).select { |entry| 
        File.directory?(File.join(path, entry)) && !(entry =='.' || entry == '..') 
      }.sort
    
      formatted_subfolders = subfolders.map do |folder_name|
        parts = folder_name.split("_")
        if parts.count >= 3
          "#{parts[0]}_#{parts[1]}_#{parts[2]}"
        else
          folder_name
        end
      end
    
      @@dialog.execute_script("addFolderToSubfolderList(#{formatted_subfolders.to_json})")
    end
    
    def self.refreshAllSubfolderLists
      @@dialog.execute_script("clearList();")
      for selected_folder in @@initial_selection do
        # UI.messagebox("selected_folder: #{selected_folder}")
        refresh_all(selected_folder)
      end
    end

    def self.clearInitialSelection
      @@initial_selection.clear
    end
    
    def self.add_callbacks
      @@dialog.add_action_callback("browseFolder") { |action_context|
        browse_folder
      }

      @@dialog.add_action_callback("listSubfolders") { |action_context, path|
        list_subfolders(path)
      }

      @@dialog.add_action_callback("refreshSubfolderList") { |action_context, path|
        list_subfolders(path)
      }

      @@dialog.add_action_callback("browseNewFolder") { |action_context|
        browse_new_folder
      }

      @@dialog.add_action_callback("refreshAllSubfolderLists") { |action_context|
        refreshAllSubfolderLists
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
