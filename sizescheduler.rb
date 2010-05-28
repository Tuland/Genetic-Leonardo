require 'polygon'

class SizeScheduler
  MAX = 50
  MIN = 1
  STEP = 1
  INCREASE_EVERY = 500                                                  # NB: il timer e' soggetto ad un bonus legato alla dimensione corrente
  PROB_FACTOR = 0.19
  
  attr_reader :start, :stop, :current, :offset, :changed, :probability
  
  # Inizializzazione dell'organizzatore che gestisce la dimensione della stringa del gene
  def initialize(min=MIN, max=MAX, step=STEP)
    @stop = max || MAX                                                  # Valore di fine                                     
    @start = min                                                        # Valore di inizio
    @current = min                                                      # Valore corrente
    @step = step                                                        # Valore di vanzamento
    @changed = false                                                    # Flag che indica il cambio di valore
    @probability =  get_probability                                     # Probabilita' della mutazione in relazione alla dimensione
    @timer = INCREASE_EVERY
    puts_report
  end
  
  # Incrementa lo stato dello scheduler e determina se e' opportuno l'avanzamento della dimensione
  def increase(count)
    if ( count == @timer && @current <= @stop )
      puts "Increase: #{@current}"  
      @current = @current + @step                                       # Incrementa il valore corrente
      update_timer
      @probability =  get_probability
      @changed = true
      @offset = (0...(Polygon::SIZE * @step)).map{rand(2)}              # Crea nuovi elementi casuali di compensazione
      puts_report
    else
      @changed = false
    end  
  end
  
  private
  
  # Definisce il prossimo incremento
  def update_timer
    @timer = @timer + INCREASE_EVERY + bonus(@current)
  end
  
  # Definisce un bonus di tempo al timer
  # * Piu' la stringa e' grande piu' ha bisogno di tempo
  def bonus(size)
    (size ** 2) / 5
  end
  
  # Definisce la probabilira' in base alla dimensione corrente
  def get_probability
    PROB_FACTOR / (@current * Polygon::SIZE)
  end
  
  # Crea un report a video
  def puts_report
    puts  "Size: #{@current * Polygon::SIZE} bits " + 
          "- Mutation prob: #{@probability}"
  end
  
  
end