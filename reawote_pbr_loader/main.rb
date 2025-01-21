module Reawote
  module ReawotePBRLoader

    @@initial_selection = []
    @@subfolder_paths = []
    @@percentage = 1.0
    @@dialog = nil
    @@load16Nrm_checked = false
    @@loadDisp_checked = false
    @@load16Disp_checked = false
    @@loadAO_checked = false

    # Create a new HTML dialog
    def self.create_dialog
      options = {
        dialog_title: 'Reawote PBR Loader',
        preferences_key: 'com.example.ReawotePBRLoader',
        style: UI::HtmlDialog::STYLE_DIALOG,
        height: 900,
        width: 500
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_size(options[:width], options[:height])
      dialog.set_file(File.join(__dir__, 'dialog.html'))
      dialog.center

      dialog
    end

    # Set the state for loading 16-bit normal maps
    def self.set_load16Nrm_state(state)
      @@load16Nrm_checked = state == 'true'
    end

    # Set the state for loading displacement maps
    def self.set_loadDisp_state(state)
      @@loadDisp_checked = state == 'true'
    end

    # Set the state for loading 16-bit displacement maps
    def self.set_load16Disp_state(state)
      @@load16Disp_checked = state == 'true'
    end

    # Set the state for loading ambient occlusion maps
    def self.set_loadAO_state(state)
      @@loadAO_checked = state == 'true'
    end

    # Allow the user to browse for a folder
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

    def self.browse_hdri
      @@initial_selection.clear
      @@subfolder_paths.clear
      selected_folder = UI.select_directory(title: "Select a Folder")
      if selected_folder
        @@initial_selection << selected_folder
        @@dialog.execute_script("updateFolderPath('#{selected_folder}')")
        # UI.messagebox("Initial Selection: #{@@initial_selection}")
      end
    end

    # Browse and import a selected model folder, attempting to load SketchUp and VRMesh files, while configuring V-Ray materials.
    def self.browse_model
      selected_model_folder = UI.select_directory(title: "Select a Model Folder")
      if selected_model_folder
        skp_files = Dir.glob(File.join(selected_model_folder, "*.skp"))
        vrmesh_files = Dir.glob(File.join(selected_model_folder, "*.vrmesh"))
    
        message = "Selected Model Folder: #{selected_model_folder}\n"
        if skp_files.empty?
          #UI.messagebox("No SketchUp documents found in the selected folder.")
          Dir.glob(File.join(selected_model_folder, "*/")).each do |subdir|
            skp_files = []
            vrmesh_files = []
            subdir_name = File.basename(subdir)
            base_pattern = subdir_name.split('_')[0, 2].join('_')
            skp_files += Dir.glob(File.join(subdir, "*.skp"))
            vrmesh_files += Dir.glob(File.join(subdir, "*.vrmesh"))
            if !skp_files.empty? && !vrmesh_files.empty?
              import_model(skp_files, vrmesh_files, selected_model_folder)
              return
            end

            Dir.glob(File.join(subdir, "#{base_pattern}*")).each do |matching_folder|
              if Dir.exist?(matching_folder)
                skp_files += Dir.glob(File.join(matching_folder, "*.skp"))
                vrmesh_files += Dir.glob(File.join(matching_folder, "*.vrmesh"))
                import_model(skp_files, vrmesh_files, selected_model_folder)
              end
            end
          end
          return
        end

        if skp_files.empty?
          UI.messagebox("No SketchUp documents found in the selected folder or its subdirectories.")
        elsif vrmesh_files.empty?
          UI.messagebox("No VRMesh found in the selected folder or its subdirectories.")
        else
          import_model(skp_files, vrmesh_files, selected_model_folder)
        end
      end
    end

    def self.assign_mat_properties(tex, model_folder)
      if tex
        tex_file_name = tex[:file]
        separator = tex_file_name.include?('\\') ? '\\' : '/'
        path_parts = tex_file_name.split(separator)
        tex_base = path_parts[-1]
        matching_files = Dir.glob(File.join(model_folder, "**", "*#{tex_base}"))
        tex_path = matching_files.first
        tex[:file] = tex_path
      end
    end

    def self.create_vray_hdri(hdri_name)
      context = VRay::Context.active
      model = context.model
      scene = context.scene
      renderer = context.renderer
      valid_sub_subfolder_names = (1..16).map { |n| "#{n}K" }
      selected_path = nil

      @@subfolder_paths.each do |path|
        last_part = path.split('/').last
        if last_part.include?(hdri_name)
          Dir.entries(path).each do |subdir|
            next if subdir == '.' || subdir == '..'  # Skip current and parent directory listings
            if valid_sub_subfolder_names.include?(subdir)
              selected_path = File.join(path, subdir)  # Update selected_path with the valid subdirectory path
              break  # Found a valid subdirectory, so we can stop looking further
            end
          end
        end
        break if selected_path  # If we've found our path, no need to continue
      end
      puts selected_path

      # Find the .hdr file in the selected path
      hdr_file = Dir.glob(File.join(selected_path, '*.hdr')).first
      unless hdr_file
        UI.messagebox("No .hdr file found in the selected folder: #{selected_path}")
        return
      end
      puts hdr_file
    
      unless scene && renderer
        UI.messagebox("V-Ray for SketchUp is not detected!")
        return
      end
    
      scene.change do
        # Create a new V-Ray material as a plugin in the scene
        hdri_plugin_path = "/#{hdri_name}"
        my_hdri_plugin = scene.create(:LightDome, hdri_plugin_path)

        bitmap_path = "/#{hdri_name}/Bitmap/Bitmap"
        bitmap = scene.create(:BitmapBuffer, bitmap_path)
        bitmap[:file] = hdr_file

        texture_path = "/#{hdri_name}/Bitmap"
        texture = scene.create(:TexBitmap, texture_path)
        texture[:bitmap] = bitmap

        my_hdri_plugin[:dome_tex] = texture
      end
    end

    def self.import_model(skp_files, vrmesh_files, selected_model_folder)
      skp_file = skp_files.first
      model = Sketchup.active_model
      definitions = model.definitions
      begin
        model.start_operation('Import SKP', true)
        componentdefinition = definitions.load(skp_file, allow_newer: true)
        if componentdefinition
          instance = model.active_entities.add_instance(componentdefinition, IDENTITY)
          context = VRay::Context.active
            # defs = model.definitions
            scene = context.scene
            renderer = context.renderer
            scene.change do

              for vrmesh_file in vrmesh_files
                file_name = File.basename(vrmesh_file, ".*")
                vrmesh_path = "/#{file_name}"
                vrmesh = scene["/#{file_name}"]
                unless vrmesh
                  UI.messagebox("Please import the model before launching V-Ray. Restart SketchUp and import the model prior to opening any V-Ray interfaces.")
                  model.abort_operation
                  return
                end
                vrmesh[:file] = vrmesh_file
              end

              puts " "
                materials = model.materials
                for material in materials
                  puts " "
                  material_name = material.name
                  #if material_name.include?(file_name)
                    material_plugin_path = "/#{material_name}"
                    material_plugin = scene[material_plugin_path]
                    diffuse_tex = scene["/#{material_name}/Base/VRayBRDF/diffuseTexBitmap/BitmapBuffer"]
                    if diffuse_tex
                      diffuse_tex_file_name = diffuse_tex[:file]
                      separator = diffuse_tex_file_name.include?('\\') ? '\\' : '/'
                      path_parts = diffuse_tex_file_name.split(separator)
                      diffuse_tex_base = path_parts[-1]
                      matching_files = Dir.glob(File.join(selected_model_folder, "**", "*#{diffuse_tex_base}"))
                      diffuse_tex_path = matching_files.first
                      diffuse_tex[:file] = diffuse_tex_path
                    end

                    glossiness_tex = scene["/#{material_name}/Base/VRayBRDF/reflectionGlossinessTexBitmap/BitmapBuffer"]
                    if glossiness_tex
                      glossiness_tex_file_name = glossiness_tex[:file]
                      separator = glossiness_tex_file_name.include?('\\') ? '\\' : '/'
                      path_parts = glossiness_tex_file_name.split(separator)
                      glossiness_tex_base = path_parts[-1]
                      matching_files = Dir.glob(File.join(selected_model_folder, "**", "*#{glossiness_tex_base}"))
                      glossiness_tex_path = matching_files.first
                      glossiness_tex[:file] = glossiness_tex_path
                    end

                    bump_tex = scene["/#{material_name}/Bump/bumpTexBitmap/BitmapBuffer"]
                    if bump_tex
                      bump_tex_file_name = bump_tex[:file]
                      separator = bump_tex_file_name.include?('\\') ? '\\' : '/'
                      path_parts = bump_tex_file_name.split(separator)
                      bump_tex_base = path_parts[-1]
                      matching_files = Dir.glob(File.join(selected_model_folder, "**", "*#{bump_tex_base}"))
                      bump_tex_path = matching_files.first
                      bump_tex[:file] = bump_tex_path
                    end

                    displacement_tex = scene["/#{material_name}/displacementTexBitmap/BitmapBuffer"]
                    if displacement_tex
                      displacement_tex_file_name = displacement_tex[:file]
                      separator = displacement_tex_file_name.include?('\\') ? '\\' : '/'
                      path_parts = displacement_tex_file_name.split(separator)
                      displacement_tex_base = path_parts[-1]
                      matching_files = Dir.glob(File.join(selected_model_folder, "**", "*#{displacement_tex_base}"))
                      displacement_tex_path = matching_files.first
                      displacement_tex[:file] = displacement_tex_path
                    end

                    metallness_tex = scene["/#{material_name}/Base/VRayBRDF/metalnessTexBitmap/Bitmap"]
                    if metallness_tex
                      metallness_tex_file_name = metallness_tex[:file]
                      separator = metallness_tex_file_name.include?('\\') ? '\\' : '/'
                      path_parts = metallness_tex_file_name.split(separator)
                      metallness_tex_base = path_parts[-1]
                      matching_files = Dir.glob(File.join(selected_model_folder, "**", "*#{metallness_tex_base}"))
                      mettalness_tex_path = matching_files.first
                      metallness_tex[:file] = mettalness_tex_path
                    end

                    reflection_tex = scene["/#{material_name}/Base/VRayBRDF/reflectionTexBitmap/BitmapBuffer"]
                    assign_mat_properties(reflection_tex, selected_model_folder)
                  end
                  @@dialog.close
                end
              else
                UI.messagebox("Failed to import file.")
              end
            rescue => e
              UI.messagebox("Error importing file: #{e.message}")
            ensure
              model.commit_operation
            end
          end


    # Allow the user to select a new folder to add to the initial selection queue, updating the dialog with subfolders if valid.
    def self.browse_new_folder(source)
      selected_folder = UI.select_directory(title: "Select a New Folder to Add to Queue")
      return unless selected_folder
    
      @@initial_selection << selected_folder
    
      valid_sub_subfolder_names = (1..16).map { |n| "#{n}K" }
      formatted_subfolders = []
      hdr_condition_met = false
    
      subfolders = Dir.entries(selected_folder).select do |entry|
        File.directory?(File.join(selected_folder, entry)) && !(entry == '.' || entry == '..')
      end.sort rescue []
    
      subfolders.each do |folder_name|
        parts = folder_name.split("_")
        formatted_name = if parts.count >= 3
                           "#{parts[0]}_#{parts[1]}_#{parts[2]}"
                         else
                           folder_name
                         end
    
        sub_subfolder_path = File.join(selected_folder, folder_name)
        sub_subfolders = Dir.entries(sub_subfolder_path).select do |entry|
          File.directory?(File.join(sub_subfolder_path, entry)) && !(entry == '.' || entry == '..')
        end rescue []
    
        case source
        when "onClickButton" # Add only folders without `.hdr` files
          if sub_subfolders.any? { |sub_subfolder| 
            valid_sub_subfolder_names.include?(sub_subfolder) &&
            !Dir.entries(File.join(sub_subfolder_path, sub_subfolder)).any? { |file| file.end_with?('.hdr') }
          }
            @@subfolder_paths << File.join(selected_folder, folder_name)
            formatted_subfolders << formatted_name
          else
            direct_sub_subfolders = Dir.entries(selected_folder).select do |entry|
              File.directory?(File.join(selected_folder, entry)) &&
              valid_sub_subfolder_names.include?(entry) &&
              !Dir.entries(File.join(selected_folder, entry)).any? { |file| file.end_with?('.hdr') }
            end rescue []
    
            if direct_sub_subfolders.any?
              @@subfolder_paths << selected_folder
              formatted_name = File.basename(selected_folder).rpartition('_')[0]
              formatted_subfolders << formatted_name
              break
            end
          end
    
        when "onHdriButton" # Add only folders with `.hdr` files
          valid_folders = sub_subfolders.select do |sub_subfolder|
            valid_sub_subfolder_names.include?(sub_subfolder) &&
            Dir.entries(File.join(sub_subfolder_path, sub_subfolder)).any? { |file| file.end_with?('.hdr') }
          end
    
          if valid_folders.any?
            @@subfolder_paths << File.join(selected_folder, folder_name)
            formatted_subfolders << formatted_name
            hdr_condition_met = true
          else
            direct_sub_subfolders = Dir.entries(selected_folder).select do |entry|
              File.directory?(File.join(selected_folder, entry)) &&
              valid_sub_subfolder_names.include?(entry) &&
              Dir.entries(File.join(selected_folder, entry)).any? { |file| file.end_with?('.hdr') }
            end rescue []
    
            if direct_sub_subfolders.any?
              @@subfolder_paths << selected_folder
              formatted_name = File.basename(selected_folder).rpartition('_')[0]
              formatted_subfolders << formatted_name
              hdr_condition_met = true
              break
            end
          end
        else
          puts "Invalid source argument for Add to Queue: #{source}"
        end
      end
    
      if formatted_subfolders.any?
        @@dialog.execute_script("addFolderToSubfolderList(#{formatted_subfolders.to_json})")
        message = hdr_condition_met ? "Folders with .hdr files added." : "Folders without .hdr files added."
        puts message
      else
        UI.messagebox("No valid folders were found to add to the queue in: #{selected_folder}")
      end
    end 

    # List all subfolders in a given path and populate the dialog with the found subfolder names.
    def self.list_subfolders(path)
      @@subfolder_paths = []
      formatted_subfolders = []
    
      valid_sub_subfolder_names = (1..16).map { |n| "#{n}K" }
      subfolders = Dir.entries(path).select do |entry| 
        File.directory?(File.join(path, entry)) && !(entry == '.' || entry == '..') 
      end.sort rescue []
    
      subfolders.each do |folder_name|
        parts = folder_name.split("_")
        formatted_name = parts.count >= 3 ? "#{parts[0]}_#{parts[1]}_#{parts[2]}" : folder_name
    
        sub_subfolder_path = File.join(path, folder_name)
        sub_subfolders = Dir.entries(sub_subfolder_path).select do |entry|
          File.directory?(File.join(sub_subfolder_path, entry)) && !(entry == '.' || entry == '..')
        end rescue []
    
        # Skip this folder if any .hdr file is found in its valid xK subfolders
        hdr_exists = sub_subfolders.any? do |sub_subfolder| 
          valid_sub_subfolder_names.include?(sub_subfolder) &&
          Dir.entries(File.join(sub_subfolder_path, sub_subfolder)).any? { |file| file.end_with?('.hdr') }
        end
    
        if hdr_exists
          puts "Skipping folder: #{folder_name} - Found .hdr file."
          next
        end
    
        if sub_subfolders.any? { |sub_subfolder| valid_sub_subfolder_names.include?(sub_subfolder) }
          @@subfolder_paths << File.join(path, folder_name)
          formatted_subfolders << formatted_name
        else
          direct_sub_subfolders = Dir.entries(path).select do |entry| 
            File.directory?(File.join(path, entry)) && valid_sub_subfolder_names.include?(entry) && !(entry == '.' || entry == '..')
          end rescue []
    
          # Skip if any .hdr file exists in these subfolders as well
          hdr_exists_direct = direct_sub_subfolders.any? do |sub_subfolder|
            Dir.entries(File.join(path, sub_subfolder)).any? { |file| file.end_with?('.hdr') }
          end
    
          if hdr_exists_direct
            puts "Skipping folder: #{folder_name} - Found .hdr file in direct subfolder."
            next
          end
    
          if direct_sub_subfolders.any?
            @@subfolder_paths << path
            formatted_name = File.basename(path).rpartition('_')[0]
            formatted_subfolders << formatted_name
            break
          end
        end
      end
    
      if formatted_subfolders.any?
        @@dialog.execute_script("populateSubfolderList(#{formatted_subfolders.to_json})")
        puts @@subfolder_paths
      else
        if @@subfolder_paths.empty?
          @@dialog.execute_script("setButtonStates(true);")
          UI.messagebox("No Reawote materials were found in selected path: #{path}")
        end
      end
    end
    
    def self.list_hdri_folders(path)
      @@subfolder_paths = []
      formatted_subfolders = []
    
      valid_sub_subfolder_names = (1..16).map { |n| "#{n}K" }
      subfolders = Dir.entries(path).select do |entry| 
        File.directory?(File.join(path, entry)) && !(entry == '.' || entry == '..') 
      end.sort rescue []
    
      subfolders.each do |folder_name|
        parts = folder_name.split("_")
        formatted_name = parts.count >= 3 ? "#{parts[0]}_#{parts[1]}_#{parts[2]}" : folder_name
    
        sub_subfolder_path = File.join(path, folder_name)
        sub_subfolders = Dir.entries(sub_subfolder_path).select do |entry|
          File.directory?(File.join(sub_subfolder_path, entry)) && !(entry == '.' || entry == '..')
        end rescue []
    
        # Check for valid xK subfolders
        valid_folders = sub_subfolders.select do |sub_subfolder| 
          valid_sub_subfolder_names.include?(sub_subfolder) && 
          Dir.entries(File.join(sub_subfolder_path, sub_subfolder)).any? { |file| file.end_with?('.hdr') }
        end
    
        if valid_folders.any?
          @@subfolder_paths << File.join(path, folder_name)
          formatted_subfolders << formatted_name
        else
          # Debug: Log why the folder was skipped
          puts "Skipping folder: #{folder_name} - No valid xK folder with .hdr file found."
          
          # Check directly in the main path for valid xK subfolders
          direct_sub_subfolders = Dir.entries(path).select do |entry| 
            File.directory?(File.join(path, entry)) && 
            valid_sub_subfolder_names.include?(entry) && 
            Dir.entries(File.join(path, entry)).any? { |file| file.end_with?('.hdr') }
          end rescue []
    
          if direct_sub_subfolders.any?
            @@subfolder_paths << path
            formatted_name = File.basename(path).rpartition('_')[0]
            formatted_subfolders << formatted_name
            break
          else
            puts "No valid xK folders with .hdr files found directly under the main path."
          end
        end
      end
    
      if formatted_subfolders.any?
        @@dialog.execute_script("populateSubfolderList(#{formatted_subfolders.to_json})")
        puts @@subfolder_paths
      else
        if @@subfolder_paths.empty?
          @@dialog.execute_script("setButtonStates(true);")
          UI.messagebox("No Reawote HDRIs were found in selected path: #{path}")
        end
      end
    end 

    def self.refresh_all(path, source)
      puts "Subfolder paths before refresh: #{@@subfolder_paths}"
      # @@subfolder_paths = []
      formatted_subfolders = []
    
      valid_sub_subfolder_names = (1..16).map { |n| "#{n}K" }
      
      subfolders = Dir.entries(path).select do |entry|
        File.directory?(File.join(path, entry)) && !(entry == '.' || entry == '..')
      end.sort rescue []
    
      subfolders.each do |folder_name|
        parts = folder_name.split("_")
        formatted_name = if parts.count >= 3
                           "#{parts[0]}_#{parts[1]}_#{parts[2]}"
                         else
                           folder_name
                         end
    
        sub_subfolder_path = File.join(path, folder_name)
        sub_subfolders = Dir.entries(sub_subfolder_path).select do |entry|
          File.directory?(File.join(sub_subfolder_path, entry)) && !(entry == '.' || entry == '..')
        end rescue []
    
        case source
        when "onClickButton"
          if sub_subfolders.any? { |sub_subfolder| 
            valid_sub_subfolder_names.include?(sub_subfolder) &&
            !Dir.entries(File.join(sub_subfolder_path, sub_subfolder)).any? { |file| file.end_with?('.hdr') }
          }
            @@subfolder_paths << File.join(path, folder_name)
            formatted_subfolders << formatted_name
          else
            direct_sub_subfolders = Dir.entries(path).select do |entry|
              File.directory?(File.join(path, entry)) && 
              valid_sub_subfolder_names.include?(entry) &&
              !Dir.entries(File.join(path, entry)).any? { |file| file.end_with?('.hdr') }
            end rescue []
        
            if direct_sub_subfolders.any?
              @@subfolder_paths << path
              formatted_name = File.basename(path).rpartition('_')[0]
              formatted_subfolders << formatted_name
              break
            end
          end

        when "onHdriButton"
          valid_folders = sub_subfolders.select do |sub_subfolder|
            valid_sub_subfolder_names.include?(sub_subfolder) &&
            Dir.entries(File.join(sub_subfolder_path, sub_subfolder)).any? { |file| file.end_with?('.hdr') }
          end
    
          if valid_folders.any?
            @@subfolder_paths << File.join(path, folder_name)
            formatted_subfolders << formatted_name
          else
            direct_sub_subfolders = Dir.entries(path).select do |entry|
              File.directory?(File.join(path, entry)) && valid_sub_subfolder_names.include?(entry) &&
              Dir.entries(File.join(path, entry)).any? { |file| file.end_with?('.hdr') }
            end rescue []
    
            if direct_sub_subfolders.any?
              @@subfolder_paths << path
              formatted_name = File.basename(path).rpartition('_')[0]
              formatted_subfolders << formatted_name
              break
            end
          end
        else
          puts "Invalid source argument: #{source}"
        end
      end
    
      if formatted_subfolders.any?
        @@dialog.execute_script("addFolderToSubfolderList(#{formatted_subfolders.to_json})")
      else
        UI.messagebox("No valid folders found in the selected path: #{path}")
      end
    end
    
    
    def self.refreshAllSubfolderLists(source)
      @@subfolder_paths.clear
      @@dialog.execute_script("clearList();")
      for selected_folder in @@initial_selection do
        # UI.messagebox("selected_folder: #{selected_folder}")
        refresh_all(selected_folder, source)
      end
      puts "Subfolder paths after refresh: #{@@subfolder_paths}"
    end

    def self.clearInitialSelection
      @@initial_selection.clear
      @@subfolder_paths.clear
    end

    # Create a V-Ray material
    def self.create_vray_material(material_name)
      context = VRay::Context.active
      model = context.model
      scene = context.scene
      renderer = context.renderer
      valid_sub_subfolder_names = (1..16).map { |n| "#{n}K" }
      selected_path = nil
      @@mix_operator_loaded = false

      @@subfolder_paths.each do |path|
        last_part = path.split('/').last
        if last_part.include?(material_name)
          Dir.entries(path).each do |subdir|
            next if subdir == '.' || subdir == '..'  # Skip current and parent directory listings
            if valid_sub_subfolder_names.include?(subdir)
              selected_path = File.join(path, subdir)  # Update selected_path with the valid subdirectory path
              break  # Found a valid subdirectory, so we can stop looking further
            end
          end
        end
        break if selected_path  # If we've found our path, no need to continue
      end

      @@mapID_list = []
      Dir.entries(selected_path).each do |filename|
        next if filename == '.' || filename == '..'
        
        full_path = File.join(selected_path, filename)
        parts = filename.split('_')
        mapID = parts[-2] if parts.length > 1
        @@mapID_list << mapID 
      end
      
      # Ensure V-Ray for SketchUp is present
      unless scene && renderer
        puts "V-Ray for SketchUp is not detected!"
        return
      end
    
      my_material_plugin = nil
      bitmap_buffer = nil
      displacement = nil
      mix_operator = nil
      
      scene.change do
        # Create a new V-Ray material as a plugin in the scene
        material_plugin_path = "/#{material_name}"
        my_material_plugin = scene.create(:MtlSingleBRDF, material_plugin_path)
        vray_material_plugin_path = "/#{material_name}/VRay Mtl"
        my_material_plugin[:brdf] = scene.create(:BRDFVRayMtl, vray_material_plugin_path)

        # if @@mapID_list.include?("DISP") || @@mapID_list.include?("DISP16")
        #   displacement_path = "/#{material_name}"
        #   displacement = scene.create(:GeomDisplacedMesh, displacement_path)
        #   # Additional logic for setting up displacement might be needed here
        # end
        
      end
    
      if my_material_plugin
    
        puts "V-Ray material '#{material_name}' created successfully."

        scene.change do

          if my_material_plugin && my_material_plugin[:brdf]


            Dir.entries(selected_path).each do |filename|
              next if filename == '.' || filename == '..'
              
              full_path = File.join(selected_path, filename)
              parts = filename.split('_')
              mapID = parts[-2] if parts.length > 1

              bitmap_plugin_path = "/#{material_name}/VRay Mtl/Bitmap/Bitmap"
              bitmap_buffer = scene.create(:BitmapBuffer, bitmap_plugin_path)
              bitmap_buffer[:file] = full_path
              nalezena = bitmap_buffer[:file]

              texture_plugin_path = "/#{material_name}/VRay Mtl/#{mapID}"
              texture_bitmap = scene.create(:TexBitmap, texture_plugin_path)
              texture_bitmap[:bitmap] = bitmap_buffer
            
              if mapID == "COL"
                if !@@loadAO_checked || !@@mapID_list.include?("AO")
                  my_material_plugin[:brdf][:diffuse] = texture_bitmap
                  my_material_plugin[:brdf][:diffuse_tex] = texture_bitmap
                else
                  if !@@mix_operator_loaded
                    mix_operator_path = "/#{material_name}/VRay Mtl/Mix (Operator)"
                    mix_operator = scene.create(:TexCompMax, mix_operator_path)
                    mix_operator[:operator] = 3
                    @@mix_operator_loaded = true

                    my_material_plugin[:brdf][:diffuse_tex] = mix_operator
                    my_material_plugin[:brdf][:diffuse] = mix_operator
                  end
                  
                  if @@mix_operator_loaded
                    bitmap_plugin_path = "/#{material_name}/VRay Mtl/Mix (Operator)/Bitmap/Bitmap"
                    bitmap_buffer = scene.create(:BitmapBuffer, bitmap_plugin_path)
                    bitmap_buffer[:file] = full_path

                    source_a_tex_path = "/#{material_name}/VRay Mtl/Mix (Operator)/#{mapID}"
                    source_a_tex = scene.create(:TexBitmap, source_a_tex_path)
                    source_a_tex[:bitmap] = bitmap_buffer

                    mix_operator[:sourceA_tex] = source_a_tex
                    mix_operator[:sourceA] =  source_a_tex
                  end
                end
              
              elsif mapID == "AO" && @@loadAO_checked
                if !@@mix_operator_loaded
                  mix_operator_path = "/#{material_name}/VRay Mtl/Mix (Operator)"
                  mix_operator = scene.create(:TexCompMax, mix_operator_path)
                  mix_operator[:operator] = 3
                  @@mix_operator_loaded = true

                  my_material_plugin[:brdf][:diffuse_tex] = mix_operator
                  my_material_plugin[:brdf][:diffuse] = mix_operator
                end
                
                if @@mix_operator_loaded
                  bitmap_plugin_path = "/#{material_name}/VRay Mtl/Mix (Operator)/Bitmap#1/Bitmap"
                  bitmap_buffer = scene.create(:BitmapBuffer, bitmap_plugin_path)
                  bitmap_buffer[:file] = full_path
                  
                  source_b_tex_path = "/#{material_name}/VRay Mtl/Mix (Operator)/#{mapID}"
                  source_b_tex = scene.create(:TexBitmap, source_b_tex_path)
                  source_b_tex[:bitmap] = bitmap_buffer

                  mix_operator[:sourceB] =  source_b_tex
                  mix_operator[:sourceB_tex] =  source_b_tex
                end

              elsif mapID == "GLOSS"
                reflect_gloss_plugin_path = "/#{material_name}/VRay Mtl/reflect_glossiness"
                tex_combine = scene.create(:TexCombineFloat, reflect_gloss_plugin_path)
                tex_combine[:texture] = texture_bitmap

                bitmap_buffer[:transfer_function] = 1
                bitmap_buffer[:gamma] = 0.7
                
                my_material_plugin[:brdf][:reflect_glossiness] = tex_combine
                my_material_plugin[:brdf][:reflect_glossiness_tex] = texture_bitmap
                my_material_plugin[:brdf][:reflect_color] = VRay::Color.new(1.0, 1.0, 1.0)
              
              elsif mapID == "METAL"
                metalness_plugin_path = "/#{material_name}/VRay Mtl/metalness"
                tex_combine = scene.create(:TexCombineFloat, metalness_plugin_path)
                tex_combine[:texture] = texture_bitmap

                bitmap_buffer[:transfer_function] = 1
                bitmap_buffer[:gamma] = 0.7

                my_material_plugin[:brdf][:metalness] = tex_combine
                my_material_plugin[:brdf][:metalness_tex] = texture_bitmap
              
              elsif mapID == "OPAC"
                opacity_plugin_path = "/#{material_name}/VRay Mtl/opacity"
                tex_combine = scene.create(:TexCombineFloat, opacity_plugin_path)
                tex_combine[:texture] = texture_bitmap

                my_material_plugin[:brdf][:opacity] = tex_combine
                my_material_plugin[:brdf][:opacity_tex] = texture_bitmap
              
              elsif mapID == "SSS"
                my_material_plugin[:brdf][:translucency_color] = texture_bitmap
                my_material_plugin[:brdf][:translucency_color_tex] = texture_bitmap
                my_material_plugin[:brdf][:translucency] = 6
              
              elsif mapID == "SHEENGLOSS"
                sheengloss_plugin_path = "/#{material_name}/VRay Mtl/sheen_glossiness"
                tex_combine = scene.create(:TexCombineFloat, sheengloss_plugin_path)
                tex_combine[:texture] = texture_bitmap

                my_material_plugin[:brdf][:sheen_glossiness_tex] = texture_bitmap
                my_material_plugin[:brdf][:sheen_glossiness] = tex_combine

              elsif mapID == "NRM" && (!@@load16Nrm_checked || !@@mapID_list.include?("NRM16"))
                bitmap_buffer[:transfer_function] = 0
                my_material_plugin[:brdf][:bump_map] = texture_bitmap
                my_material_plugin[:brdf][:bump_map_tex] = texture_bitmap
                my_material_plugin[:brdf][:bump_type] = 1
              
              elsif mapID == "NRM16" && @@load16Nrm_checked

                bitmap_buffer[:transfer_function] = 0
                my_material_plugin[:brdf][:bump_map] = texture_bitmap
                my_material_plugin[:brdf][:bump_map_tex] = texture_bitmap
                my_material_plugin[:brdf][:bump_type] = 1
              
              elsif mapID == "DISP" && @@loadDisp_checked && (!@@load16Disp_checked || !@@mapID_list.include?("DISP16"))
                displacement_path = "/#{material_name}_DISP"
                displacement = scene.create(:GeomDisplacedMesh, displacement_path)

                disp_bitmap_path = "/#{material_name}/Bitmap/Bitmap"
                disp_bitmap = scene.create(:BitmapBuffer, disp_bitmap_path)
                disp_bitmap[:file] = full_path
                disp_bitmap[:transfer_function] = 0

                disp_path = "/#{material_name}/Bitmap"
                disp_texture = scene.create(:TexBitmap, disp_path)
                disp_texture[:bitmap] = disp_bitmap

                displacement[:displacement_amount] = 0.1
                displacement[:displacement_tex_color] = disp_texture

              elsif mapID == "DISP16" && @@loadDisp_checked && @@load16Disp_checked
                displacement_path = "/#{material_name}_DISP"
                displacement = scene.create(:GeomDisplacedMesh, displacement_path)
                
                disp_bitmap_path = "/#{material_name}/Bitmap/Bitmap"
                disp_bitmap = scene.create(:BitmapBuffer, disp_bitmap_path)
                disp_bitmap[:file] = full_path
                disp_bitmap[:transfer_function] = 0

                disp_path = "/#{material_name}/Bitmap"
                disp_texture = scene.create(:TexBitmap, disp_path)
                disp_texture[:bitmap] = disp_bitmap

                displacement[:displacement_amount] = 0.1
                displacement[:displacement_tex_color] = disp_texture

              end
            end
          end
        end

      else
        puts "Failed to create V-Ray material '#{material_name}'."
      end
    end

    
    def self.add_callbacks
      @@dialog.add_action_callback("browseFolder") { |action_context|
        browse_folder
      }

      @@dialog.add_action_callback("browseModel") {
        browse_model
      }

      @@dialog.add_action_callback("browseHdri") { |action_context|
        browse_hdri
      }
      
      @@dialog.add_action_callback("listSubfolders") { |action_context, path|
        list_subfolders(path)
      }

      @@dialog.add_action_callback("listHdriFolders") { |action_context, path|
        list_hdri_folders(path)
      }

      @@dialog.add_action_callback("refreshSubfolderList") { |action_context, path|
        list_subfolders(path)
      }

      @@dialog.add_action_callback("browseNewFolder") do |action_context, source|
        if source.nil? || source.empty?
          puts "Error: Missing 'source' argument in browseNewFolder callback."
        else
          browse_new_folder(source)
        end
      end

      @@dialog.add_action_callback("refreshAllSubfolderLists") do |action_context, source|
        if source.nil? || source.empty?
          puts "Error: Missing 'source' argument in refreshAllSubfolderLists callback."
        else
          refreshAllSubfolderLists(source)
        end
      end

      @@dialog.add_action_callback("createVrayMaterial") { |action_context, subfolder_name|
        create_vray_material(subfolder_name)
      }

      @@dialog.add_action_callback("createVrayHdri") { |action_context, subfolder_name|
        create_vray_hdri(subfolder_name)
      }

      @@dialog.add_action_callback("setLoad16NrmState") do |action_context, state|
        set_load16Nrm_state(state)
      end

      @@dialog.add_action_callback("setLoadDispState") do |action_context, state|
        set_loadDisp_state(state)
      end

      @@dialog.add_action_callback("setLoad16DispState") do |action_context, state|
        set_load16Disp_state(state)
      end

      @@dialog.add_action_callback("setLoadAOState") do |action_context, state|
        set_loadAO_state(state)
      end

      @@dialog.add_action_callback("subfolderSelected") { |action_context, subfolder_name, index|
        if index >= 0 && index < @@subfolder_paths.length
          selected_path = @@subfolder_paths[index]

          if File.directory?(selected_path)
            begin
              preview_subfolder_name ||= Dir.entries(selected_path).find do |entry|
                entry.downcase.include?('preview') && File.directory?(File.join(selected_path, entry))
              end

              if preview_subfolder_name
                preview_subfolder_path = File.join(selected_path, preview_subfolder_name)
                
                target_file_name = Dir.entries(preview_subfolder_path).find do |entry|
                  base_name = File.basename(entry, ".*").downcase
                  (base_name.include?('fabric') || base_name.include?('sphere')) && File.file?(File.join(preview_subfolder_path, entry))
                end

                # If no 'fabric' or 'sphere' file is found, look for 'PLANE'
                if target_file_name.nil?
                  target_file_name = Dir.entries(preview_subfolder_path).find do |entry|
                    base_name = File.basename(entry, ".*").downcase
                    base_name.include?('plane') && File.file?(File.join(preview_subfolder_path, entry))
                  end
                end

                if target_file_name
                  full_target_file_path = File.join(preview_subfolder_path, target_file_name)
                  subfolder_display_name = File.basename(selected_path)  # Extract the subfolder name from the path
                  # Use execute_script to call the JavaScript function to update the image and subfolder name
                  @@dialog.execute_script("updateMaterialPreviewImage('#{full_target_file_path}', '#{subfolder_display_name}')")
                  # UI.messagebox("Found target file: #{full_target_file_path}")
                
                else
                  puts "Didnt found target file in: #{preview_subfolder_path}"
                end
              end
            rescue => e
              puts "Failed to list directory contents: #{e.message}"
            end
          else
            puts "Directory does not exist: #{selected_path}"
          end
        else
          puts @@subfolder_paths
          puts index
          puts "No match found for subfolder: #{subfolder_name}, Index: #{index}"
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
