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
      '[%02d:%02d] ($%04X)' % [track, sector, offset]
    end
  end
end
