module D64
  class Block
    attr_accessor :track, :sector

    def initialize(track, sector)
      @track  = track
      @sector = sector
    end

    def offset
      D64::Image.offset(self)
    end

    def to_s
      '[%02X:%02X]' % [track, sector]
    end
  end
end
