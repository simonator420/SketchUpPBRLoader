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

    def self.set_load16Nrm_state(state)
      @@load16Nrm_checked = state == 'true'
    end

    def self.set_loadDisp_state(state)
      @@loadDisp_checked = state == 'true'
    end

    def self.set_load16Disp_state(state)
      @@load16Disp_checked = state == 'true'
    end

    def self.set_loadAO_state(state)
      @@loadAO_checked = state == 'true'
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
        
        valid_sub_subfolder_names = (1..16).map { |n| "#{n}K" }
        
        formatted_subfolders = subfolders.map do |folder_name|
          parts = folder_name.split("_")
          formatted_name = if parts.count >= 3
            "#{parts[0]}_#{parts[1]}_#{parts[2]}"
          else
            folder_name
          end
    
          sub_subfolders = Dir.entries(File.join(selected_folder, folder_name)).select { |entry| 
            File.directory?(File.join(selected_folder, folder_name, entry)) && !(entry =='.' || entry == '..') 
          }
          
          if sub_subfolders.any? { |sub_subfolder| valid_sub_subfolder_names.include?(sub_subfolder) }

            full_path = File.join(selected_folder, folder_name)
            @@subfolder_paths << full_path
    
            formatted_name
          else
            nil
          end
        end.compact
    
        if formatted_subfolders.any?
          # puts "Formatted Subfolders: #{formatted_subfolders}"
          @@dialog.execute_script("addFolderToSubfolderList(#{formatted_subfolders.to_json})")
        else
          UI.messagebox("No Reawote materials were found in selected path: #{selected_folder}")
        end
      end
    end       
    

    def self.list_subfolders(path)
      @@subfolder_paths.clear
      subfolders = Dir.entries(path).select { |entry| 
        File.directory?(File.join(path, entry)) && !(entry =='.' || entry == '..') 
      }.sort
    
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

          @@subfolder_paths << File.join(path, folder_name)
    
          formatted_name
        else
          nil
        end
      end.compact  # Remove nil elements from the array
    
      # Print and execute script only if formatted_subfolders is not empty
      if formatted_subfolders.any?
        @@dialog.execute_script("populateSubfolderList(#{formatted_subfolders.to_json})")
      else
        UI.messagebox("No Reawote materials were found in selected path: #{path}")
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
      # puts "Map ID List for material #{material_name}: #{@@mapID_list.join(', ')}"
      
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
        
        # puts "Diffuse color set to: #{my_material_plugin[:brdf][:diffuse]}"
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
          # puts "Selected Path: #{selected_path}"

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
