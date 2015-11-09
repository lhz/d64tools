require "d64/block"
require "d64/sector"
require "d64/block_map"

module D64
  # http://vice-emu.sourceforge.net/vice_15.html#SEC278

  class Image
    attr_reader :num_tracks, :filename
    attr_accessor :name, :interleave

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
      (count - 1).times.each_with_object([Block.new(track, sector)]) do |i, blocks|
        sector = (sector + il) % count
        sector = (sector + 1) % count while visited[sector]
        blocks << Block.new(track, sector)
        visited[sector] = true
      end
    end

    def initialize(interleave: 10, num_tracks: 35, name: '')
      @interleave = interleave
      @num_tracks = num_tracks
      @name = name
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

    def reserve_blocks(track, first = 0, blocks = 1, interleave = 3)
      interleaved = D64::Image.interleaved_blocks(track, interleave, first)
      while blocks > 0
        block = interleaved.shift or
          fail "No free blocks to reserve on track #{track}."
        redo unless bam.free_on_track(track)[block.sector]
        logger.debug "Marking block #{'[%02d:%02d]' % [block.track, block.sector]} as used."
        bam.mark_as_used block.track, block.sector
        blocks -= 1
      end
      bam.commit
    end

    def format(title, disk_id)
      offset  = 256 * 357
      title   = title.bytes[0, 16]
      disk_id = (disk_id + "  ").bytes[0, 2]
      dos_ver = "A".ord
      dos_id  = "2A".bytes
      @image = Array.new(256 * 683) { 0 }
      @image[offset, 2] = [18, 1]
      @image[offset + 0x02] = dos_ver
      @image[offset + 0x90, 27] = [0xA0] * 27
      @image[offset + 0x90, title.size] = title
      @image[offset + 0xA2, 2] = disk_id
      @image[offset + 0xA5, 2] = dos_id
      @image[offset + 0x100, 2] = [0, 255]
      @bam = nil
      (1..35).each do |tn|
        D64::Image.sectors_per_track(tn).times do |sn|
          bam.mark_as_unused tn, sn unless tn == 18 && sn < 2
        end
      end
      bam.commit
    end

    def add_file(name, content)
      block = @last_file_block
      while content && content.size > 0
        block = bam.allocate_with_interleave(block, interleave) or
          fail "No free blocks, disk full!"
        # logger.debug "add_file: allocated block #{block}"
        @image[@last_file_block.offset, 2] = [block.track, block.sector] if @last_file_block
        @image[block.offset, 256] = [0, 255] + content[0, 254] + [255] * (254 - content[0, 254].size)
        content = content[254..-1]
        @last_file_block = block
      end
    end

    def logger
      D64.logger
    end
    
    private

    def sector_data(block)
      @image[Image.offset(block), 256]
    end
  end
end
