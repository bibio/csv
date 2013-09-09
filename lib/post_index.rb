# coding: utf-8
require 'csv'

class Postcode
  attr_accessor :id,:code, :pref, :town, :other

  def to_s
    "#{@id},#{@code},#{@pref},#{@town},#{@other}"
  end

  class << self
    def parse(str)
      obj = self.new
      obj.id,obj.code,obj.pref,obj.town,obj.other = str.split(/,/)
      obj.id = obj.id.to_i
      obj
    end
  end
end

class PostIndex

  def initialize
    @csvfile = "KEN_ALL.CSV"
    @idxfile = "ken_all.idx"
    @idx = {}
    @postcodes = []
  end

  attr_reader :idx, :postcodes
  attr_accessor :csvfile, :idxfile

  #
  # インデックスの作成
  #
  def make
    id = 0
    postcodes = []
    File.open(@idxfile, "w:utf-8") do |fp|
      fp.puts "#data"  # データ部
      CSV.foreach(@csvfile, encoding:"cp932:UTF-8") { |row|
        pc = Postcode.new
        pc.id = id+=1
        pc.code  = row[2]
        pc.pref  = row[6]
        pc.town  = row[7]
        pc.other = row[8]
        if pc.other == "以下に掲載がない場合"
          pc.other = ""
        end

        ## 出現文字列の文字毎のidをインデックスとする
        (pc.pref+pc.town+pc.other).split(//).uniq.each { |ch|
          @idx[ch] ||= []
          @idx[ch].push(fp.pos)
        }
        postcodes << pc
        fp.puts pc
      }
      fp.puts "#idx"  # インデックス部を出力
      # インデックス部分の出力
      @idx.each { |s,v|
        # 差分圧縮する
        prev = 0
        comp_v = v.sort.map { |m| d = m - prev; prev = m; next d }

        fp.puts "#{s}:#{comp_v*","}"
      }
    end
  end

  # 
  # インデックスの読み込み
  #
  def load
    mode = nil
    File.open(@idxfile, "r:utf-8") do |fp|

      # インデックス部の先に読み込み
      fp.each_line do |line|
        if mch = /^#(data|idx)/.match(line)
          mode = mch.captures.first.to_sym
        elsif mode == :data
          next
        elsif mode == :idx
          ch,str = line.chomp.split(/:/)
          @idx[ch] ||= []

          # 差分圧縮の解凍
          prev = 0
          exrct_v = str.split(/,/).map { |m| d = m.to_i + prev; prev += m.to_i; next d }
          @idx[ch].push(*exrct_v)
        end
      end
    end
  end

  #
  # 検索
  #
  def search(query)
    ## 空白抜いて検索後を分割
    ids = nil
    ## UTF-8に変換
    query.encode('UTF-8').strip.split(//).each do |qch|
      if @idx[qch]
        if ids.nil?
          ids = @idx[qch].dup
        else
          ids = ids & @idx[qch]
        end
      end
    end

    File.open(@idxfile, "r:utf-8") do |fp|
      uniq_ids = ids.uniq.sort
      puts "ヒット件数: #{uniq_ids.size}"
      puts "-----"
      uniq_ids.uniq.sort.each do |i|
        fp.seek i
        pc = Postcode.parse(fp.readline.chomp)

        #      pc = @postcodes[i]
        if pc 
          puts "#{pc.code},#{pc.pref},#{pc.town},#{pc.other}"
        end
      end
    end
  end
end

class PostIndexRunner
  def initialize(argv)
    case argv[0]
    when "search"
      argv.shift
      search argv
    when "make"
      idx = PostIndex.new
      idx.make
    else
      usage
    end
  end

  private

  def search(argv)
    idx = PostIndex.new
    idx.load
    idx.search argv*""
  end

  def usage
    STDERR.puts <<EOF
#{File.basename $0} - search address in postcode table 

  Commands are
    search  <WORD>    Search for <WORD>.
    make              Generate index.

EOF
  end
end
