require 'opengl'
include Gl,Glu,Glut

require 'realpicture'
require 'individual'
require 'helper'
require 'sizescheduler'

module Enumerable
  
  # Crea un insieme di intervalli consecutivi in cui ogni item ha uno spazio grande quanto il proprio value 
  def weighted_wheel
    total = 0.0
    ranges = map do |item|
      value = yield(item)                                               # Calcola il valore attraverso il blocco (es: metodo) che viene passato
      start = total                                                     # Valore di inizio di item all'interno dell'intervallo (ruota)
      total += value                                                    # Grandezza complessiva di tutti gli intervalli (incrementato di volta in volta)
      [start, value, item]                                              # Memorizzazione dell'intervallo in un array
    end
    return total, ranges
  end
  
  # Simula una roulette wheel per scegliere determinati elementi di un insieme
  # * Ogni elemento ha una diversa probabilità di essere selezionato e ciò dipende dal proprio peso
  # * Il modo di valutare il peso è definito da &weight_valuation
  # * round corrisponde al numero di selezioni che deve operare la ruota
  def roulette(round, &weight_valuation)
    total, ranges = weighted_wheel(&weight_valuation)
    selected = []                                                       # Insieme degli elementi selezionati dalla roulette
    while true
      pointer = (rand * total) % total                                  # Genera un puntatore casuale
      ranges.each do |start, length, item|
        if start <= pointer && pointer < start + length                 # Verifica se il puntatore è compreso nell'intervallo corrente
          selected.push(item)                                           # Includi l'item nei selezionati
        end
        return selected unless selected.size < round                    # Cicla fino a quando è completa la selezione
      end
    end
  end
  
end

class Evolution
  
  attr_reader :generation, :best
  attr_accessor :flush
  
  REPORT_PATH='report.txt'                                              # Percorso del file di report
  
  GENERATION_SIZE = 70                                                  # Dimensione di ogni generazione
  MATING_POOL_SIZE = 30                                                 # Dimensione di una selezione attraverso roulette all'interno della generazione
  TOURNAMENT_SIZE = 3                                                   # Dimensione dei tornei
  ELITISM_SIZE = 2                                                      # Numero degli individui appartenenti all'elite
  
  CROSSOVER = {                                                         # Tipologie di crossover
    "uniform"   =>  "uniform_crossover",                                # Crossover uniforme                               
  	"single_p"  =>  "one_point_crossover",                              # Crossover ad un punto
  	"double_p"  =>  "two_point_crossover"                               # Crossover a due punti
  }.freeze
  
  DEFAULT_CROSSOVER = CROSSOVER["uniform"]
  
  GENERATION_BUILDER = {                                                # Tipologie di costruttori di generazione
    "roulette"    => "build_roulette_generation",                       # Con selezione a roulette
    "tournament"  => "build_tournament_generation"                      # Con selezione a torneo
  }.freeze
  
  DEFAULT_GENERATION_BUILDER = GENERATION_BUILDER["tournament"] 
  
  CROSSOVER_PROB = 0.95                                                 # Probabilità del crossover
  # MUTATION_PROB = 0.0001                                              # Probabilità della mutazione (Valore gestito dallo scheduler)
  
  REPORT_EVERY = 10                                                     # temporizzazione (num. di generazioni) dei resoconti testuali
  SAVE_EVERY = 200                                                     # temporizzazione (num. di generazioni) della creazione delle immagini
  
  # Dimensione della pressione di selezione
  case DEFAULT_GENERATION_BUILDER
  when GENERATION_BUILDER["roulette"]
    SELECTION_SIZE = MATING_POOL_SIZE                                   
  when GENERATION_BUILDER["tournament"]
    SELECTION_SIZE = TOURNAMENT_SIZE
  end

  # Inizializzazione dell'evoluzione
  # * Crea una generazione
  # * Definisce la selezione
  # * Imposta un contatore e i riferimenti temporali
  # * Legge l'immagine originale
  def initialize(real_picture, size_scheduler , gen_size=GENERATION_SIZE, sel_size=SELECTION_SIZE, eli_size=ELITISM_SIZE)
    raise "Evolution.new: invalid params" if (gen_size <= sel_size ||
                                              sel_size <= eli_size || 
                                              eli_size <= 0)
    @scheduler = size_scheduler                                         # Gestore del numero dei poligoni
    @real_picture = real_picture                                        # Immagne originale
    @generation = (0...gen_size).map do                                 # Crea una generazione aleatoria composta da stringhe binarie 
      Individual.new(@scheduler.start) { rand(2) }                      # Il numero di poligoni è definito dallo scheduler 
    end 
    @generation_size = gen_size                                         # Numero di individui nella popolazione
    @selection_size = sel_size                                          # Numero degli individui da salvare
    @elitism_size = eli_size
    @count = 0                                                          # Conteggio delle generazioni
    @start_time = now_formatted                                         # Istante iniziale dell'evoluzione
    @step_time = Time.now
    @file_report = File.open(REPORT_PATH, 'w')
    report_parameters
  end
  
  # Passo di evoluzione
  # * Esegue una selezione
  # * Accoppia casualmente i sopravvissuti
  # * Crea una nuova nuova generazione di individui
  def step
    @generation.each{ |i| i.fitness =  valuate(i) } if @count == 0      # Calcola la fitness di ogni individuo della prima generazione
    @count += 1                                                         # Incrementa conteggio
    @scheduler.increase(@count)                                         # Aggiorna lo scheduler dello stato dell'ovoluzione
    @scheduler.changed ? upgrade_generation : next_generation           # In base allo scheduler aggiorna la generazione (nuova dim individui) o crea la generazione successiva
    remember_fittest
    write_report if @count % REPORT_EVERY == 0
    @best.draw
    glFlush
    save_picture if @count % SAVE_EVERY == 0
    end

    # Crea report a video e su file
    def write_report(report_path=REPORT_PATH)
      time_now = Time.now
      time = time_now - @step_time
      @step_time = time_now
      puts "Generation: #{@count} " +                                   # Report su video                      
           "- best fitness: #{@best.fitness} " +
           "- time: #{time}"
      @file_report << "#{@scheduler.current} , " +
                      "#{@count} , " +
                      "#{@best.fitness}\n"                           
    end

    # Esegue un salvataggio su file dell'immagine artificiale
    def save_picture
      fit_str = @best.fitness.to_s[2..-1]
      file =  "#{@start_time}_" +                                       # Nome del file
              "#{now_formatted}_" + 
              "gen_#{@count}_" + 
              "fit_#{fit_str}" + 
              ".png"
      artificial_picture.write(file)
      puts "Written #{file}"
    end
  
  private
  
  # Crea la generazion successiva
  # * Una parte è costituita dalla parte e da un'altra dall'elite che sopravvive da una generazione all'altra
  def next_generation
    elite = fittests(@elitism_size)
    send(DEFAULT_GENERATION_BUILDER)                                    # Esegue il costruttore della generazione di default [Reflection]
    elite.each { |i|  @generation << i }
  end
  
  def build_roulette_generation
    survivors = roulette_selection                                      # Individua i sopravvissuti dopo una selezione (mating pool)
    @generation = (0...(@generation_size - @elitism_size)).map do       # Crea la nuova generazione
      mating { survivors.random }                                       # Accoppiamento scegliendo casualmente all'interno della selezione tramite roulette
    end
  end
  
  def build_tournament_generation
    @generation = (0...(@generation_size - @elitism_size)).map do       # Crea la nuova generazione
      mating { tournament_selection }                                   # Accoppiamento scegliendo i genitori attraverso i tornei
    end
  end
  
  # Accoppiamento
  def mating
    father, mother = yield, yield
    son = Individual.new(                                               # Crea un nuovo individuo facendo riprodurre il genitore dominante con uno dei sopravvisuti
                          @scheduler.current,                           # Numero dei poligoni
                          father.procreate( mother,                     # Genestring
                                            CROSSOVER_PROB, 
                                            @scheduler.probability,
                                            DEFAULT_CROSSOVER)
                        )
    son.fitness = valuate(son)
    son
  end
  
  # Aggiorna la generazione incrementando la dimensione degli individui (incremento del numero di poligoni)
  # * l'incremento è gestito da scheduler_size 
  def upgrade_generation
    elite = fittests(@elitism_size) 
    @generation = (0...@generation_size).map do
      i = Individual.new(
                          @scheduler.current,
                          elite.random.genestring + @scheduler.offset
                        )
      i.fitness = valuate(i) 
      i
    end
  end
  
  # Valuta quanto l'individuo è adatto a sopravviere 
  # * La valutazione viene fatta attraverso il confronto con l'immagine originale
  # * La fitness è inversamente proporzionale alla differenca dell'immagine reale con quella artificiale
  def valuate(individual)
    individual.draw
    glFlush if @flush                                                   # Forza l'esecuzione dei comandi GL
    1.0 - artificial_picture.difference(@real_picture.image)[1]         # Normalized mean error (0.0 e 1.0)                                       
  end
  
  # Ordina per fitness i migliori n membri della generazione 
  def fittests(n)
    @generation.sort{ |x,y| y.fitness <=> x.fitness  }[0...n]           # Ordinamento inverso con i primi n numeri                
  end
  
  # Selezione attraverso roulette wheel
  def roulette_selection(sel_size=@selection_size)
    @generation.roulette(sel_size){ |i| i.fitness }
  end
  
  # Selezione a torneo
  def tournament_selection(sel_size=@selection_size)
    best = nil
    sel_size.times do
      challenger = @generation.random
      if (best.nil? || challenger.fitness > best.fitness)
        best = challenger
      end
    end
    best
  end
  
  # ricorda l'individuo con la migliore fitness
  # * Confronta i migliori delle ultime due generazioni e ne determina il vincente
  def remember_fittest
    new_best = fittests(1).first
    @best = new_best 
  end
  
  # Immagine artificiale ricavata dal gene
  def artificial_picture
    pixels = glReadPixels(  
                            0, 0,                                       # Punto di origine
                            @real_picture.width, @real_picture.height,  # Dimensioni
                            GL_RGB,                                     # Formato dei pixel
                            GL_UNSIGNED_SHORT                           # Tipo dei dati
                          )
  	@image ||= Magick::Image.new( @real_picture.width,                  # Se non esiste ancora la variabile la inizializza
  	                              @real_picture.height)
  	@image.import_pixels(
  	                        0, 0,                                       # Punto di origine
  	                        @real_picture.width, @real_picture.height,  # Dimensioni 
  	                        "RGB",                                      # Formato dei pixel
  	                        pixels,                                     # pixel data
  	                        Magick::ShortPixel                          # Tipo dei dati
  	                    )
  	@image.flip!                                                        # Rotazione di 180 gradi
    @image
  end
  
  # Formatta il tempo attuale
  def now_formatted
    Time.now.localtime.strftime('%Y%m%d%H%M%S')                         # Ora locale: AnnoMeseGiornoOraMinutiSecondi
  end
  
  def report_parameters
    puts "Generation size: #{@generation_size}"
    puts "Selection pressure: #{@selection_size}"
    puts "Elitism size: #{@elitism_size}"
    puts "Crossover type: #{DEFAULT_CROSSOVER}"
    puts "Generation builder (selection type): #{DEFAULT_GENERATION_BUILDER}"
    puts "Crossover probability: #{CROSSOVER_PROB}"
    puts "Mutation factor: #{SizeScheduler::PROB_FACTOR}"
    puts "Report file: #{REPORT_PATH}"
    puts "***"
  end
  
end

display = lambda do
  @evolution.step
end

keyboard = lambda do |key, x, y|
  case (key)
  when ?\e                                                              # Esce (esc)
    exit(0)
  when ?s                                                               # Salva su file l'immagine
    @evolution.save_picture
  when ?d                                                               # Disegna tutti i poligoni presi in condiserazione (on/off)
    @evolution.flush = @evolution.flush ? false : true
  end
end

# Main

real_picture = RealPicture.new(ARGV[0])
size_scheduler = SizeScheduler.new(1, ARGV[1])
@evolution = Evolution.new(real_picture, size_scheduler)

glutInit
glutInitDisplayMode(GLUT_SINGLE | GLUT_RGB | GLUT_ALPHA)
glutInitWindowSize( real_picture.width, 
                    real_picture.height )
glutInitWindowPosition(100, 100)
glutCreateWindow($0)
glEnable(GL_BLEND)
glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
glutDisplayFunc(display)
glutKeyboardFunc(keyboard)
glutIdleFunc(display)
glutMainLoop


