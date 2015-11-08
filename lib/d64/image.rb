require "d64/block"
require "d64/sector"
require "d64/block_map"

module D64
  # http://vice-emu.sourceforge.net/vice_15.html#SEC278

  class Image
    attr_reader :num_tracks, :filename
    attr_accessor :name

    def self.read(filename)
      di = new
      di.read(filename)
      di
    end

    def self.offset(block)
      (@offsets ||= build_offset_table)[block.track - 1][block.sector]
    end

    def self.build_offset_table
      ss = -1
      40.times.map do |i|
        tn = i + 1
        sectors_per_track(tn).times.map do
          ss += 1
          ss * 256
        end
      end
    end

    def self.sectors_per_track(track)
      @spt ||= [0] + [21] * 17 + [19] * 7 + [18] * 6 + [17] * 10
      @spt[track]
    end

    def initialize
      @num_tracks = 35
      @name = ''
    end

    def to_s
      "<D64::Image:#{object_id.to_s(16)} @filename=#{filename}>"
    end

    def read(file)
      @filename = file
      @image    = File.binread(filename).bytes
    end

    def write(file = filename)
      File.open(file, 'wb') { |f| f.write @image.pack('C*') }
    end

    def sector(block)
      block = Block.new(block[0], block[1]) if block.is_a?(Array)
      Sector.new(self, block, sector_data(block))
    end

    def bam
      block = Block.new(18, 0)
      @bam ||= BlockMap.new(self, block, sector_data(block))
    end

    def directory_chain
      sector([18, 0]).chain
    end
    
    def allocate_sector(opts = {})
      block = bam.allocate(opts) or
        fail "Failed to allocate sector!"
      Sector.new(self, block, [0] * 256)
    end

    def commit_sector(sector)
      @image[Image.offset(sector.block), 256] = sector.bytes
    end

    def commit_bam
      @image[Image.offset(@bam.block) + 4, 140] = @bam.bytes[4, 140]
    end

    private

    def sector_data(block)
      @image[Image.offset(block), 256]
    end
  end
end
