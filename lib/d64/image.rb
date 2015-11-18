require "d64/block"
require "d64/sector"
require "d64/block_map"
require "d64/directory"
require "d64/entry"

module D64
  # http://vice-emu.sourceforge.net/vice_15.html#SEC278

  class Image
    attr_reader :num_tracks, :filename, :directory
    attr_accessor :name, :interleave, :last_file_sector

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

    def self.interleaved_blocks(track, il = interleave, sector = 0)
      count = sectors_per_track(track)
      visited = Array.new(count) { false }
      visited[sector] = true
      blocks = (count - 1).times.each_with_object([Block.new(track, sector)]) do |i, blocks|
        sector = (sector + il) % count
        sector = (sector + 1) % count while visited[sector]
        blocks << Block.new(track, sector)
        visited[sector] = true
      end
      blocks
    end

    def initialize(interleave: 10, num_tracks: 35, name: '')
      zerofill!
      @interleave = interleave
      @num_tracks = num_tracks
      @name = name
      @directory = Directory.new(self)
    end

    def zerofill!
      @image = Array.new(256 * 683) { 0 }
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
      commit_sector(bam)
      # @image[Image.offset(@bam.block) + 4, 140] = @bam.bytes[4, 140]
    end

    def reserve_blocks(track, first = 0, blocks = 1, interleave = 3)
      interleaved = D64::Image.interleaved_blocks(track, interleave, first)
      while blocks > 0
        block = interleaved.shift or
          fail "No free blocks to reserve on track #{track}."
        redo unless bam.free_on_track(track)[block.sector]
        logger.debug "Marking block #{block} as used."
        bam.mark_as_used block.track, block.sector
        blocks -= 1
      end
      bam.commit
    end

    def format(title, disk_id)
      logger.info "Formatting image with title '#{title}' and disk id #{disk_id}"
      zerofill!
      bam.format title, disk_id
      bam.link_to directory.sectors.first
    end

    def add_file(name, content, type = :prg)
      logger.info "Adding file #{name} of size #{content.size}"
      entry = Entry.new(self, name, type)
      entry.store content
      blocks = entry.sectors.map(&:block)
      logger.info "  File uses #{blocks.size} blocks from #{blocks.first} to #{blocks.last}"
    end

    def logger
      D64.logger
    end
    
    private

    def pad_name(name)
      name.bytes + [0xA0] * (16 - name.bytes.size)
    end

    def sector_data(block)
      @image[Image.offset(block), 256]
    end
  end
end
