require 'enumerator'


class Array
  
  # Trasforma un'array contenente valori binari in un valore decimale
  def to_val
    self.join.to_i(2)
  end
  
  # Aggiunge una normalizzazione a to_val (valore compreso fra 0.0 e 1.0)
  # * Se viene passato true come parametro si usano valori compresi fra -1.0 e 1.0
  # * Il valore di default e' false 
  def to_val_norm(negative_enabled = false, z = 1.0)
    if negative_enabled
      num = self[1..-1]
      ((-1) ** self[0]) * num.to_val_norm(false, z)                   # Il primo valore viene usato per stabilire il segno
    else
      z * self.to_val / (2 ** self.size - 1.0) 
    end
  end

end

class Polygon
  
  attr_reader :weight, :rgba, :vertex_x, :vertex_y
  
  VERTEX_NUM = 3                                                      # Numero dei vertici del poligno (traingolo)
                                                                          
  WEIGHT_SIZE = 3                                                     # Bits x il peso
  PRIMARYCOLOR_SIZE = 2                                               # Bits x il colore primario R=2, G=2, B=2
  RGB_SIZE = 3 * PRIMARYCOLOR_SIZE
  
  VERTEX_X_SIZE = 5                                                   # Bits x vertice X=6, Y=6 
  SIZE =  WEIGHT_SIZE +                                               # Bits x poligono
          RGB_SIZE +
          VERTEX_NUM * (VERTEX_X_SIZE * 2)
          
  ZOOM = 1.3
  
  # Inizializzazione del poligono
  def initialize(array)
    raise "Polygon.new: unvalid parameter size" if array.size != SIZE
    a = array.dup
    # Peso
    @weight = a.slice!(0...WEIGHT_SIZE).to_val
    # Colore nel formato RGB
    rgba_str = a.slice!(0...RGB_SIZE)
    @rgba = []
    rgba_str.each_slice(PRIMARYCOLOR_SIZE) do |pcolor|
      @rgba << pcolor.to_val_norm
    end
    # Vertici
    @vertex_x = []                                                    # Array contentente le ascisse dei vertici
    @vertex_y = []                                                    # Array contentente le ordinate dei vertici
    VERTEX_NUM.times do
      @vertex_x << a.slice!(0...VERTEX_X_SIZE).to_val_norm(true,ZOOM)
      @vertex_y << a.slice!(0...VERTEX_X_SIZE).to_val_norm(true,ZOOM)
    end
  end  
  
end