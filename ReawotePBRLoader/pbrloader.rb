# Plugin Name: Reawote PBR Loader

module ReawotePBRLoader
    extend self
  
    def create_ui
      # Create a new HTML dialog
      dialog = UI::HtmlDialog.new({
        :dialog_title => "Reawote PBR Loader",
        :preferences_key => "com.example.ReawotePBRLoader",
        :width => 400,
        :height => 150,
        :left => 100,
        :top => 100,
        :resizable => false,
        :style => UI::HtmlDialog::STYLE_DIALOG
      })
  
      # Set the HTML content of the dialog
      html = <<~HTML
        <html>
          <head>
            <script>
              function onClickButton() {
                // Add your button click logic here
                alert("Browse Clicked!");
              }
            </script>
          </head>
          <body style="text-align: center; padding: 10px;">
            <div style="float: left; width: 50%;">
              <label style="font-size: 16px;">Material Folder:</label>
            </div>
            <div style="float: right; width: 50%;">
              <button style="font-size: 16px;" onclick="onClickButton()">Browse</button>
            </div>
          </body>
        </html>
      HTML
  
      dialog.set_html(html)
  
      # Show the dialog
      dialog.show
    end
  end
  
  # Run the plugin
  ReawotePBRLoader.create_ui
  