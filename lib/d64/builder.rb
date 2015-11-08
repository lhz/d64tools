require 'logger'

module D64
  class Builder
    attr_writer :logger

    def self.build_all(specs)
      specs = [specs] unless specs.is_a?(Array)
      specs.each do |spec|
        builder = new(spec)
        builder.build
      end
    end

    def initialize(spec)
      @spec = spec
      logger.debug "Spec: #{spec.inspect}"
    end

    def build
      logger.info "Building image '#{image_file}'"
      # FIXME: Implement internally
      `c1541 -format #{title},#{disk_id} d64 #{image_file}`
      if hidedir
        reserve_hidden_directory track: hidedir[:track], blocks: hidedir[:blocks]
      end
      `c1541 -attach #{image_file} #{c1541_write_opts}`
    end

    private

    def reserve_hidden_directory(track: , blocks: , interleave: 3)
      logger.info "Reserving room for hidden directory on track #{track}"
      blocks ||= D64::Image.sectors_per_track(track) - 1
      image.reserve_blocks track, 0, 1 # BAM copy
      image.reserve_blocks track, 1, blocks
      image.write image_file
    end

    def image_file
      @spec[:image]
    end

    def image
      @image ||= D64::Image.read(image_file)
    end

    def title
      @spec[:title]
    end

    def disk_id
      @spec[:id]
    end

    def interleave
      @spec[:interleave] || 10
    end

    def files
      Array(@spec[:files])
    end

    def hidedir
      @spec[:hidedir]
    end

    def c1541_write_opts
      writes = files.map do |fs|
        "-write #{fs[:source]} #{fs[:target]}"
      end
      writes.join ' '
    end

    def logger
      D64.logger
    end
  end
end
