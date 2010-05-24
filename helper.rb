module Enumerable
  
  # Sceglie un elemento casuale di indice compreso fra 0 e (size-1)
  def random
    self[rand(size)]
  end
  
end