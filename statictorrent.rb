#!/usr/bin/ruby
require 'rubygems'
require 'bencode'
require 'base32'
require 'cgi'
require 'digest/sha1'
require 'fileutils'

class Torrent
  def self.str2hex(str)
    str.unpack('C*').map{|v|"%02x" % v}.join
  end

  class Info
    def initialize(info)
      @info = info
      @info_hash = Digest::SHA1.digest(BEncode.dump(info))
      @files = info['files']
      @piece_length = info['piece length']
      @name = info['name']
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
  downloaddir = "#{ENV['HOME']}/Downloads"
  torrent = Torrent.new(tname)
  info = torrent.info
  name = "#{downloaddir}/#{info.name}"
  pieces = info.pieces.clone
  piece_length = info.piece_length

  piece = nil
  info.files.each do |file|
    file_size = file['length']
    filename = "#{name}/#{file['path'][0]}"
    File.open(filename, 'rb') do |fd|
      loop do
        if piece.nil?
          piece = fd.read(piece_length)
        else
          piece += fd.read(piece_length - piece.size)
        end
        break if piece.size < piece_length
        piece_hash = Digest::SHA1.digest(piece)
        if pieces.shift == piece_hash # good piece
          yield(piece_hash, piece)
        end
        piece = nil
      end
    end
  end

  if piece
    piece_hash = Digest::SHA1.digest(piece)
    if pieces.shift == piece_hash # good piece
      yield(piece_hash, piece)
    end
  end
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
  def store(piece_hash, piece)
    File.open("#{@dir}/#{Torrent.str2hex(piece_hash)}", 'wb') do |fd|
      fd.write(piece)
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

distributed_storage = DistributedStorage.new
distributed_storage << LocalStorage.new('dropbox')
distributed_storage << LocalStorage.new('ubuntuone')
distributed_storage << LocalStorage.new('spideroak')
distributed_storage << LocalStorage.new('gmailfs')
distributed_storage << LocalStorage.new('usbmemory')
distributed_storage << LocalStorage.new('sdcard')
distributed_storage << LocalStorage.new('hgdrop')
distributed_storage << LocalStorage.new('rubydrop')

begin
  distributed_storage.open
  load_torrent('Fedora-13-i686-Live.torrent') do |piece_hash, piece|
    distributed_storage.store(piece_hash, piece)
  end
ensure
  distributed_storage.close
end