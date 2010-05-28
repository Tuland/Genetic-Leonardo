require 'helper'
require 'polygon'
require 'enumerator'


class Array
  
  # Mutazione
  # * Muta il bit di ogni carattere della stringa con una determinata probabilita (passata per parametro)
  def mutation!(probability)
    self.each_index do |i|
      self[i] = self[i] ^ 1 if probability >= rand                    # Esegue lo XOR del bit (con una data probabilita)    
    end
    self
  end
  
  # Crossover uniforme
  # * Crea una maschera binaria
  # * Se nella maschera c'e' un 1 copia il bit del padre altrimenti quello della madre
  def uniform_crossover(other)
    size = self.size
    model = "%0#{size}b"                                              # Stringa binaria di una definita dimensione con 0 come riempitivo
    mask = (model % (rand(2**size)))                                  # Crea una maschera binaria casuale
    son_str = (0...size).map do |i|                                   # Crea il figlio
      mask[i,1] == "1" ? self[i] : other[i]                           # Analizza la maschera: 1->self , 0->other
    end
    son_str
  end
  
  # Crossover ad un punto
  def one_point_crossover(other)
    point_crossover(other, 1)
  end
  
  # Crossover a due punti
  def two_point_crossover(other)
    point_crossover(other, 2)
  end
  
  # Crossover ad n punti
  def point_crossover(other, n)
    indexes = (0...self.size).to_a                                    # Insieme degli indici possibili
    points = []                                                       # Insieme di punti di taglio del crossover
    n.times { points.push(indexes.delete_at(rand(indexes.size))) }    # Prende casualmente n indici (diversi) possibili e li include in points
    a, b = self, other                                                
    son_str = (0...self.size).map do |i|
      a, b = b, a if points.include?(i)                               # Se incontra un punto di crossover effettua uno swap
      a[i]                                                            # Elemento da includere in son
    end
    son_str
  end
  
end


class Individual
  
  attr_accessor :fitness, :genestring
  
  OPACITY = 0.7
  
  # Inizializza una la stringa binaria del gene
  # * E' possibile passare un blocco per scegliere gli elementi della stringa binaria. Es: rand(2)
  # * Senza il blocco e' generata una stringa completamente casuale con il metodo rand
  # * Passando una string viene utilizzata quella come genestring e non viene fatta alcuna inizializzazione
  def initialize(polygons_num ,genestring=nil)
    @genestring_size = Polygon::SIZE * polygons_num
    if genestring.nil?
        @genestring = (0...@genestring_size).map do                   
          block_given?  ? yield : rand                                # Verifica se e' stato passato un blocco: SI) esegue blocco NO) valore casuale
        end
    else
      @genestring = genestring
    end
  end
  
  # Procreazione: accoppiamento con un altro individuo
  # * Sceglie un individuo all'interno di mates ed esegue il crossover e la mutazione
  # * Le probabilita del crossover e della mutazione sono definite rispettivamente da crossover_prob e mutation_prob 
  def procreate(mate, crossover_prob, mutation_prob, crossover_method_name)
    mate_str = mate.genestring
    son_str = self.genestring.dup                                     # La stringa del figlio e' per ora un clone di quella del padre
    if crossover_prob >= rand                                         # Se rientra nella probabilita esegue il crossover se no usa se stesso
      son_str = son_str.send(crossover_method_name, mate_str)         # [Reflection] Esegue il metodo di crossover scelto con parametro 'mate'
    end
    son_str.mutation!(mutation_prob)                                  # Mutazione del figlio con una data probabilita
    son_str
  end
  
  # Disegna i poligoni che sono descritti all'interno della stringa del gene
  def draw
    glClear(GL_COLOR_BUFFER_BIT)                                      # Pulizia dei buffer
    polygons = []                                                     # Inizializzazione dell'insieme dei poligoni
    @genestring.each_slice(Polygon::SIZE) do |pstring|                # Inizializzazione dei poligoni tramite estrazione dalla stringa del gene
      polygons << Polygon.new(pstring)
    end
    polygons.sort!{|x,y| x.weight <=> y.weight}                       # Ordinamento dei poligoni in base al loro peso
    polygons.each do |p|
      glColor4f(p.rgba[0], p.rgba[1], p.rgba[2], OPACITY)             # Definisce il colore del poligono
      glBegin(GL_POLYGON)
      Polygon::VERTEX_NUM.times do |i|                                # Definisce i vertici del poligono
        glVertex2f(p.vertex_x[i], p.vertex_y[i])
      end
      glEnd
    end
  end
  
  
end