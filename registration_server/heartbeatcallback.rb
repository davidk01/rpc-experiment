class HeartbeatCallback
  
  def initialize(beat, wipe)
    @wipe = wipe
    @machine = PartialReaderDSL::PartialReaderMachine.protocol do |m|
      m.consume(2)
      m.buffer_transform do |context|
        if context.buffer == "OK"
          $logger.debug "Heartbeat OK. Resetting machine."
          beat.call; m.jump(-1)
        else
          $logger.error "Did not recognize heartbeat message: #{context.buffer}."
          wipe.call
        end
      end
    end
  end
  
  def call(monitor)
    $logger.debug "Reading heartbeat data."
    begin
      @machine.call(monitor.io)
    rescue EOFError
      $logger.error "EOFError from #{monitor.io.remote_address}."
      @wipe.call
    end
  end
  
end