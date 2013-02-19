# encoding: utf-8
require 'iTunesWalkmanSync/version'
require 'iTunesWalkmanSync/logger'
require 'mp3info'
require 'rmagick'

module ITunesWalkmanSyncCommand

  # main routine
  def self.execute(stdout, args=[])
    begin
      Log.info("start iTunesWalkmanSync batch")
      conf = YAML.load_file("etc/config.yml")
	  Log.info("start mp3 sync")
	  Log.info(" from: #{conf['itunes_dir']}")
	  Log.info(" to:   #{conf['walkman_dir']}")

      sync(conf)

      Log.info("complete iTunesWalkmanSync batch")
    rescue => ex
      Log.err("abnormal exit iTunesWalkmanSync, because #{ex}")
      Log.debug("Exception: #{ex.message} #{ex.backtrace}")
    end
  end

  # sync routine
  def self.sync(conf)
    itunes_dir = conf['itunes_dir']
    walkman_dir = conf['walkman_dir']
    except_authors = conf['except_authors']
    except_albums = conf['except_albums']

    # iTunesからmp3ファイルの全アルバムリストを作成
    all_album_list = []
    author_list = Dir::entries(itunes_dir)
    author_list.each do |author|
      next if except_authors.include?(author.encode('utf-8', Encoding::UTF8_MAC))
      next if author =~ /^\./
      next if File::ftype("#{itunes_dir}/#{author}") != "directory"
      album_list = Dir::entries("#{itunes_dir}/#{author}")
      album_list.each do |album|
        next if album =~ /^\./
        next if except_albums.include?("#{author}/#{album}".encode('utf-8', Encoding::UTF8_MAC))
        next if File::ftype("#{itunes_dir}/#{author}/#{album}") != "directory"
        all_album_list << "#{author}/#{album}"
      end
    end

    # 各アルバムに対して処理を実行
    all_album_list.each_with_index do |album, idx|
    #  break if idx > 20
    
    #  puts "processing #{album}"
      dir_itunes = "#{itunes_dir}/#{album}"
      dir_walkman = "#{walkman_dir}/#{album}"
    
      # walkman側のファイルチェック - 存在/タイムスタンプ
      walkman_isnew = false
      if File::exists?(dir_walkman) && File::ftype(dir_walkman)
    #    puts "dir exists"
        file_list_itunes = Dir::entries(dir_itunes)
        file_list_walkman = Dir::entries(dir_walkman)
        song_list_itunes = []
        song_list_walkman = []
    	file_list_itunes.each do |song|
      	  next if song =~ /^\./ or song == "Thumbs.db"
          next if File::ftype("#{dir_itunes}/#{song}") != "file"
    	  song_list_itunes << song
    	end
    	file_list_walkman.each do |song|
      	  next if song =~ /^\./
          next if File::ftype("#{dir_walkman}/#{song}") != "file"
    	  song_list_walkman << song
    	end
        if song_list_itunes.size == song_list_walkman.size
    	  walkman_isnew = true
    	  song_list_itunes.each_with_index do |song, song_idx|
    		if File::exists?("#{dir_walkman}/#{song}")
       	      mtime_itunes = File::mtime("#{dir_itunes}/#{song}")
    	      mtime_walkman = File::mtime("#{dir_walkman}/#{song}")
              if mtime_itunes>(mtime_walkman+1)
      	        Log.info("#{song} - #{mtime_itunes} / #{mtime_walkman+1} (#{mtime_itunes>(mtime_walkman+1)})")
      	  	    walkman_isnew = false
    		    break
    		  end
            else
    		  Log.info("no file @walkman: #{song}")
       	      walkman_isnew = false
    	      break
    		end
    	  end
    	end
      end
  
    #  walkman_isnew = false if album =~ /^AKB/
      if walkman_isnew
        Log.debug("#{album} -> skip")
    	next
      end
    
      Log.info("#{album} -> copy")
      # コピー先ディレクトリの作成
      unless File::exists?(dir_walkman)
        unless File::exists?(File.dirname(dir_walkman))	  
        Dir::mkdir(File.dirname(dir_walkman))
         Log.info("mkdir #{File.dirname(dir_walkman)}")
    	end
        Dir::mkdir(dir_walkman)
         Log.info("mkdir #{dir_walkman}")
      end
    
      # コピー先ディレクトリのファイル削除
      file_list_walkman = Dir::entries(dir_walkman)
      file_list_walkman.each do |song|
        next if song =~ /^\./
        next if File::ftype("#{dir_walkman}/#{song}") != "file"
        FileUtils.rm("#{dir_walkman}/#{song}")
    	Log.info("delete #{dir_walkman}/#{song}")
      end
      
      # ファイルコピー
      file_list_itunes = Dir::entries(dir_itunes)
      song_list = []
      file_list_itunes.each do |song|
        next if song =~ /^\./ or song == "Thumbs.db"
        next if File::ftype("#{dir_itunes}/#{song}") != "file"
        song_list << song
      end
      song_list.each do |song|
        FileUtils.cp("#{dir_itunes}/#{song}", "#{dir_walkman}/#{song}")
        Log.info("copy #{song}, itunes->walkman")
      end
    
      # mp3タグの変更
      song_list = song_list.sort
      
      # 二枚組判定
      discs_flg = false
    #  puts "#{dir_walkman}/#{song_list[0]}"
      Mp3Info.open("#{dir_walkman}/#{song_list[0]}", :encoding=>"utf-16be") do |mp3|
        tag_tpa = mp3.tag2["TPA"]
    	if tag_tpa
    	  tag_tpas = tag_tpa.split('/')
    #	puts "#{tag_tpas[1].to_i > 1}"
    	  discs_flg = true if tag_tpas[1].to_i > 1
    	end
      end
      Log.info("二枚組以上！") if discs_flg == true
    
      # mp3タグの変更：２枚組以上の曲順変換、アルバム名にアーティスト名追加
      song_list.each_with_index do |song, songidx|
        Mp3Info.open("#{dir_walkman}/#{song}", :encoding=>"utf-16be") do |mp3|
          artist = mp3.tag2.TP1
          artist = mp3.tag2.TP2 if mp3.tag2.TP2
          artist = mp3.tag2.TPE1 if mp3.tag2.TPE1
          artist = mp3.tag2.TPE2 if mp3.tag2.TPE2
    	  album_title = mp3.tag2.TAL
    	  album_title = mp3.tag2.TALB if mp3.tag2.TALB
    #	  puts artist
    #	  puts album
    #	  mp3.tag2.keys.each do |k|
    #        next if k =~ /PIC/
    #        puts "#{k}: #{mp3.tag2[k]}"
    #	  end
    
    	  # アルバムアートバックアップ
    #	  puts album_title
    #	  puts artist
    	  if discs_flg || album_title !~ /^#{artist}/
            if mp3.tag2["PIC"]
              text_encoding, mime_type, picture_type, picture_data = mp3.tag2["PIC"].unpack("c Z* c a*")
    #          imgfile = "#{File.basename(file, ".*")}.#{mime_type.sub('image/','')}"
              File.open("backupimg", "w") {|f|
                f.print picture_data  # 最初の1バイト目の\000を削除
    #            f.print picture_data.sub(/^\000/, '')  # 最初の1バイト目の\000を削除
              }
              path = 'backupimg'
              image = Magick::Image.read(path).first
              image.format = 'JPEG'
              tmp_path = 'backupimg_jpeg'
              image.write(tmp_path) {
                self.quality = 100
              }
    		  
              mp3.tag2.remove_pictures
    #          file = File.open("backupimg", "rb")
              file = File.open("backupimg_jpeg", "rb")
              mp3.tag2.add_picture(file.read)
    #          mp3.tag2.add_picture(file.read, { mime: mime_type })
    		  file.close
            end
          end
    	
    	 # トラック振り直し
    	  if discs_flg
    #	    puts mp3.tag2["TRK"]
    #	    puts mp3.tag["tracknum"]
    #		puts "-> #{songidx+1}/#{song_list.length}"
    #		puts "-> #{songidx+1}"
    		mp3.tag2["TRK"] = "#{songidx+1}/#{song_list.length}"
    #		mp3.tag["tracknum"] = songidx+1
    	  end
    	  
    	  # アーティスト名追記
    	  if album =~ /^Compilations/
    		mp3.tag2.TAL = "VA/#{album_title}" if mp3.tag2.TAL
    		mp3.tag2.TALB = "VA/#{album_title}" if mp3.tag2.TALB
    	  elsif album_title !~ /^#{artist}/
    	    artist_no_the = artist
    	    artist_no_the = $1 if artist_no_the =~ /^[Tt][Hh][Ee]\s(.*)/ 
     	    mp3.tag2.TAL = "#{artist_no_the}/#{album_title}" if mp3.tag2.TAL
    		mp3.tag2.TALB = "#{artist_no_the}/#{album_title}" if mp3.tag2.TALB
    #	     mp3.tag["album"] = "#{artist}/#{album}"
    #        puts "new album name: #{artist}/#{album}"
    	  end
    	  
    	end
      end
    
    end
    
    # WALKMAN側のみに存在するディレクトリの削除
    Log.info("==== WALKMAN側のみに存在するディレクトリの削除 ====")
    
    all_album_list_walkman = []
    author_list = Dir::entries(walkman_dir)
    author_list.each do |author|
      next if author =~ /^\./
      next if File::ftype("#{walkman_dir}/#{author}") != "directory"
      album_list = Dir::entries("#{walkman_dir}/#{author}")
      album_list.each do |album|
        next if album =~ /^\./
        next if File::ftype("#{walkman_dir}/#{author}/#{album}") != "directory"
        all_album_list_walkman << "#{author}/#{album}"
      end
    end
    
    all_album_list_walkman.each do |album|
      unless all_album_list.include?(album)
        file_list = Dir::entries("#{walkman_dir}/#{album}")
    	file_list.each do |f|
    	  next if f =~ /^\./
    	  FileUtils.rm("#{walkman_dir}/#{album}/#{f}")
          Log.info("delete #{walkman_dir}/#{album}/#{f}")
    	end
        FileUtils.rmdir("#{walkman_dir}/#{album}")
        Log.info("delete #{walkman_dir}/#{album}")
      end
    end

  end
  


end
