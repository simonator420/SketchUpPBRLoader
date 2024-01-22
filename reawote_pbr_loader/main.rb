module Reawote
  module ReawotePBRLoader

    @@initial_selection = []
    @@subfolder_paths = []
    @@percentage = 1.0
    @@dialog = nil

    def self.create_dialog
      options = {
        dialog_title: 'Reawote PBR Loader',
        preferences_key: 'com.example.ReawotePBRLoader',
        style: UI::HtmlDialog::STYLE_DIALOG,
        height: 750,
        width: 500
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_size(options[:width], options[:height])
      dialog.set_file(File.join(__dir__, 'dialog.html'))
      dialog.center

      dialog
    end

    def self.browse_folder
      @@initial_selection.clear
      @@subfolder_paths.clear
      selected_folder = UI.select_directory(title: "Select a Folder")
      if selected_folder
        @@initial_selection << selected_folder
        @@dialog.execute_script("updateFolderPath('#{selected_folder}')")
        # UI.messagebox("Initial Selection: #{@@initial_selection}")
      end
    end

    def self.browse_new_folder
      selected_folder = UI.select_directory(title: "Select a New Folder to Add to Queue")
      if selected_folder
        @@initial_selection << selected_folder
        # UI.messagebox("Initial Selection: #{@@initial_selection}")
    
        subfolders = Dir.entries(selected_folder).select { |entry| 
          File.directory?(File.join(selected_folder, entry)) && !(entry =='.' || entry == '..') 
        }.sort
        
        # Define the valid sub-subfolder names
        valid_sub_subfolder_names = (1..16).map { |n| "#{n}K" }
        
        formatted_subfolders = subfolders.map do |folder_name|
          parts = folder_name.split("_")
          formatted_name = if parts.count >= 3
            "#{parts[0]}_#{parts[1]}_#{parts[2]}"
          else
            folder_name
          end
    
          # Check if the subfolder has at least one valid sub-subfolder
          sub_subfolders = Dir.entries(File.join(selected_folder, folder_name)).select { |entry| 
            File.directory?(File.join(selected_folder, folder_name, entry)) && !(entry =='.' || entry == '..') 
          }
          
          if sub_subfolders.any? { |sub_subfolder| valid_sub_subfolder_names.include?(sub_subfolder) }
            # Add the full path of the subfolder to @@subfolder_paths if valid
            full_path = File.join(selected_folder, folder_name)
            @@subfolder_paths << full_path
    
            formatted_name
          else
            nil  # Exclude the subfolder if it doesn't have a valid sub-subfolder
          end
        end.compact  # Remove nil elements from the array
    
        # Print and execute script only if formatted_subfolders is not empty
        if formatted_subfolders.any?
          puts "Formatted Subfolders: #{formatted_subfolders}"
          @@dialog.execute_script("addFolderToSubfolderList(#{formatted_subfolders.to_json})")
        else
          UI.messagebox("No Reawote materials were found in the selected folder: #{selected_folder}")
        end
      end
    end       
    

    def self.list_subfolders(path)
      @@subfolder_paths.clear # Clear previous paths
      subfolders = Dir.entries(path).select { |entry| 
        File.directory?(File.join(path, entry)) && !(entry =='.' || entry == '..') 
      }.sort
    
      # Define the valid sub-subfolder names
      valid_sub_subfolder_names = (1..16).map { |n| "#{n}K" }
    
      formatted_subfolders = subfolders.map do |folder_name|
        parts = folder_name.split("_")
        formatted_name = if parts.count >= 3
          "#{parts[0]}_#{parts[1]}_#{parts[2]}"
        else
          folder_name
        end
    
        # Check if the subfolder has at least one valid sub-subfolder
        sub_subfolders = Dir.entries(File.join(path, folder_name)).select { |entry| 
          File.directory?(File.join(path, folder_name, entry)) && !(entry =='.' || entry == '..') 
        }
    
        if sub_subfolders.any? { |sub_subfolder| valid_sub_subfolder_names.include?(sub_subfolder) }
          # Add the full path of the subfolder to @@subfolder_paths if valid
          @@subfolder_paths << File.join(path, folder_name)
    
          formatted_name
        else
          nil  # Exclude the subfolder if it doesn't have a valid sub-subfolder
        end
      end.compact  # Remove nil elements from the array
    
      # Print and execute script only if formatted_subfolders is not empty
      if formatted_subfolders.any?
        puts "Formatted Subfolders: #{formatted_subfolders}"
        @@dialog.execute_script("populateSubfolderList(#{formatted_subfolders.to_json})")
      else
        UI.messagebox("No Reawote materials were found in the selected folder: #{path}")
      end
    end
        

    def self.refresh_all(path)
      subfolders = Dir.entries(path).select { |entry| 
        File.directory?(File.join(path, entry)) && !(entry =='.' || entry == '..') 
      }.sort
    
      formatted_subfolders = subfolders.map do |folder_name|
        parts = folder_name.split("_")
        formatted_name = if parts.count >= 3
          "#{parts[0]}_#{parts[1]}_#{parts[2]}"
        else
          folder_name
        end
    
        # Add the full path of the subfolder to @@subfolder_paths
        full_path = File.join(path, folder_name)
        @@subfolder_paths << full_path
    
        formatted_name
      end
    
      @@dialog.execute_script("addFolderToSubfolderList(#{formatted_subfolders.to_json})")
    end
    
    
    def self.refreshAllSubfolderLists
      @@subfolder_paths.clear
      @@dialog.execute_script("clearList();")
      for selected_folder in @@initial_selection do
        # UI.messagebox("selected_folder: #{selected_folder}")
        refresh_all(selected_folder)
      end
    end

    def self.clearInitialSelection
      @@initial_selection.clear
      @@subfolder_paths.clear
    end

    def self.create_vray_material(material_name)
      # Initialize the V-Ray context
      context = VRay::Context.active
      model = context.model
      scene = context.scene
      renderer = context.renderer
      
      # Ensure V-Ray for SketchUp is present
      unless scene && renderer
        puts "V-Ray for SketchUp is not detected!"
        return
      end
      
      # Start a scene change transaction
      scene.change do
        # Create a new V-Ray material as a plugin in the scene
        material_plugin_path = "/#{material_name}"
        my_material_plugin = scene.create(:MtlSingleBRDF, material_plugin_path)
        my_material_plugin[:diffuse] = VRay::Color.new(0.95,0.95,0.95)
        
      end
    
      puts "V-Ray material '#{material_name}' with an additional VRayMtl layer created successfully."
    end
    

    def self.color_to_vraycolor(color)
      VRay::Color.new(color.red / 255.0, color.green / 255.0, color.blue / 255.0)
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

      @@dialog.add_action_callback("createVrayMaterial") { |action_context, subfolder_name|
        create_vray_material(subfolder_name)
      } 

      @@dialog.add_action_callback("subfolderSelected") { |action_context, subfolder_name, index|
        if index >= 0 && index < @@subfolder_paths.length
          selected_path = @@subfolder_paths[index]
          puts "Selected Path: #{selected_path}"

          if File.directory?(selected_path)
            begin
              preview_subfolder_name = Dir.entries(selected_path).find do |entry|
                entry.downcase == 'preview' && File.directory?(File.join(selected_path, entry))
              end

              if preview_subfolder_name
                preview_subfolder_path = File.join(selected_path, preview_subfolder_name)
                
                target_file_name = Dir.entries(preview_subfolder_path).find do |entry|
                  base_name = File.basename(entry, ".*").downcase
                  (base_name.include?('fabric') || base_name.include?('sphere')) && File.file?(File.join(preview_subfolder_path, entry))
                end

                if target_file_name
                  full_target_file_path = File.join(preview_subfolder_path, target_file_name)
                  subfolder_display_name = File.basename(selected_path)  # Extract the subfolder name from the path
                  # Use execute_script to call the JavaScript function to update the image and subfolder name
                  @@dialog.execute_script("updateMaterialPreviewImage('#{full_target_file_path}', '#{subfolder_display_name}')")
                  # UI.messagebox("Found target file: #{full_target_file_path}")
                
                else
                  UI.messagebox("Didnt found target file in: #{preview_subfolder_path}")
                end
              end
            rescue => e
              UI.messagebox("Failed to list directory contents: #{e.message}")
            end
          else
            UI.messagebox("Directory does not exist: #{selected_path}")
          end
        else
          UI.messagebox("No match found for subfolder: #{subfolder_name}, Index: #{index}")
        end
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
