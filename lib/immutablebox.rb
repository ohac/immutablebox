require 'rubygems'
require 'bencode'
require 'base32'
require 'cgi'
require 'digest/sha1'
require 'fileutils'
require 'zlib'

IB_DIR = '.ib'

class Torrent
  def self.str2hex(str)
    str.unpack('C*').map{|v|"%02x" % v}.join
  end

  class Info
    def initialize(info)
      @info = info
      @info_hash = Digest::SHA1.digest(BEncode.dump(info))
      @piece_length = info['piece length']
      @name = info['name']
      @files = info['files'] || [{
        'length' => info['length'], 'path' => [@name]
      }]
      pieces = info['pieces']
      @pieces = (pieces.size / 20).times.map{|i| pieces[i * 20, 20]}
    end

    attr :info
    attr :info_hash
    attr :files
    attr :piece_length
    attr :name
    attr :pieces

    def to_s
      "magnet:?xt=urn:btih:%s" % Base32.encode(@info_hash)
    end

    def inspect
      Torrent.str2hex(@info_hash)
    end
  end

  def initialize(filename)
    torrent = BEncode.load(File.read(filename))
    @announce = torrent['announce']
    @creation_date = torrent['creation date']
    @info = Info.new(torrent['info'])
  end

  attr :info
  attr :creation_date
  attr :announce

  def to_s
    "%s&tr=%s" % [@info.to_s, CGI.escape(@announce)]
  end

  def inspect
    @info.inspect
  end
end

def load_torrent(tname)
  torrent = Torrent.new(tname)
  info = torrent.info
  pieces = info.pieces.clone
  piece_length = info.piece_length

  piece = nil
  info.files.each do |file|
    file_size = file['length']
    fd = if file['path'][0] != IB_DIR
      filename = file['path'].join('/')
      File.open(filename, 'rb')
    end
    begin
      loop do
        if fd
          if piece.nil?
            piece = fd.read(piece_length)
            break unless piece
          else
            piece += fd.read(piece_length - piece.size)
          end
        else
          break unless piece
          piece += "\000" * file_size
        end
        break if piece.size < piece_length
        piece_hash = Digest::SHA1.digest(piece)
        if pieces.shift == piece_hash # good piece
          yield(piece_hash, piece)
        end
        piece = nil
      end
    ensure
      fd.close if fd
    end
  end

  if piece
    piece_hash = Digest::SHA1.digest(piece)
    if pieces.shift == piece_hash # good piece
      yield(piece_hash, piece)
    end
  end
end

def walk(path, &block)
  Dir.entries(path).select{|d| !(/\A\.+\z/.match d)}.each do |e|
    file = File.join(path, e)
    if File.directory?(file)
      walk(file, &block)
    else
      yield file
    end
  end
end

def split_path(path)
  d = path
  rv = []
  loop do
    d, f = File.split(d)
    rv.insert(0, f)
    break if d == '.'
  end
  rv
end

def make_torrent(name, path, tracker, priv)
  torrent_piece_size = 2 ** 18
  torrent_pieces = []
  piece = ''
  gapn = 0
  files = []
  walk(path) do |file|
    next if /#{IB_DIR}\// === file
    fileinfo = { 'path' => split_path(file) }
    files << fileinfo
    filesize = 0
    File.open(file, 'rb') do |fd|
      loop do
        data = fd.read(torrent_piece_size - piece.size)
        break if data.nil?
        piece << data
        if piece.size == torrent_piece_size
          torrent_pieces << Digest::SHA1.digest(piece)
          filesize += piece.size
          piece = ''
        end
      end
    end
    if piece.size > 0
      filesize += piece.size
      fileinfo['length'] = filesize
      gapsize = torrent_piece_size - piece.size
      gapfile = "#{IB_DIR}/gap/#{gapn}"
      gapimage = "\000" * gapsize
      fileinfo = { 'length' => gapsize, 'path' => gapfile.split('/') }
      files << fileinfo
      gapn += 1
      piece << gapimage
      torrent_pieces << Digest::SHA1.digest(piece)
      piece = ''
    else
      fileinfo['length'] = filesize
    end
  end

  torrent = {
    'announce' => tracker,
    'created by' => 'statictorrent 0.0.0',
    'creation date' => Time.now.to_i,
    'info' => {
      'length' => torrent_piece_size * torrent_pieces.size,
      'name' => name,
      'private' => priv ? 1 : 0,
      'pieces' => torrent_pieces.join,
      'piece length' => torrent_piece_size,
      'files' => files,
    }
  }
  BEncode.dump(torrent)
end

class Storage
  def open
  end
  def close
  end
end

class LocalStorage < Storage
  def initialize(dir)
    @dir = dir
  end
  def open
    FileUtils.mkdir_p(@dir)
  end
  def compress?(piece)
    [' ', "\n", "\000"].map{|c| piece.count(c)}.max < 16
  end
  def store(piece_hash, piece)
    File.open("#{@dir}/#{Torrent.str2hex(piece_hash)}", 'wb') do |fd|
      fd.write(compress?(piece) ? piece : Zlib::Deflate.deflate(piece))
    end
  end
end

class DistributedStorage < Storage
  def initialize
    @storages = []
  end
  def <<(storage)
    @storages << storage
    self
  end
  def open
    @storages.each(&:open)
  end
  def close
    @storages.each(&:close)
  end
  def store(piece_hash, piece)
    dice = piece_hash.unpack('L').first % @storages.size
    @storages[dice].store(piece_hash, piece)
  end
end
