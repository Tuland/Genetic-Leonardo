begin
	require "RMagick"
rescue Exception
	puts "RMagick is not installed properly"
	exit
end

class RealPicture
  
  attr_reader :width, :height, :image
  
  IMAGE_PATH = 'image.jpg'
  
  # Inizializzazione mediante lettura da una immagine 
  def initialize(path_file=IMAGE_PATH)
    @image = Magick::Image.read(path_file).first
    @height = @image.rows
    @width = @image.columns
  end

end
