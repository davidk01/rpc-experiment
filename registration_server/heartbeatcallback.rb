class HeartbeatCallback
  
  def initialize(beat, wipe)
    @wipe = wipe
    @machine = PartialReaderDSL::PartialReaderMachine.protocol do
      consume(2); buffer_transform do |ctx|
        if ctx.buffer == "OK"
          $logger.debug "Heartbeat OK. Resetting machine."
          beat.call; ctx.jump(-1)
        else
          $logger.error "Did not recognize heartbeat message: #{ctx.buffer}."
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