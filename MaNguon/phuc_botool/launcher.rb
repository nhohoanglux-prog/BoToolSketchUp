# encoding: UTF-8
# @name: Bộ Tool SketchUp
# @version: 1.0.0
# @date: 2026-11-26
#
# Bảng tool giống panel Tool Launcher của Photoshop: quét tools/*/main.rb, đọc các dòng @name/@group/@desc/
# @version/@date/@icon/@module ở đầu file, hiện danh sách có tìm kiếm (không dấu) và chia nhóm, bấm là chạy
# (nạp file tool rồi gọi <@module>.show). Nút Cập nhật đọc capnhat.json trên kho GitHub, tải hết rồi mới ghi đè,
# sau đó nạp lại ngay (không cần tắt SketchUp).
require 'json'
require 'fileutils'

module PhucBoTool
  ROOT = __dir__ unless defined?(ROOT)
  REPO = 'nhohoanglux-prog/BoToolSketchUp'.freeze unless defined?(REPO)
  PREF = 'PhucBoTool'.freeze unless defined?(PREF)
  @dlg = nil unless defined?(@dlg)
  @reqs = [] unless defined?(@reqs)
  @loaded = {} unless defined?(@loaded)
  @pending = nil unless defined?(@pending)

  # ---------- đọc đầu file ----------
  def self.header(path)
    t = File.read(path, encoding: 'UTF-8')[0, 3000].to_s
    h = {}
    t.scan(/@(\w+):[ \t]*([^\r\n]+)/) { |k, v| h[k] ||= v.strip }
    h
  rescue StandardError
    {}
  end

  def self.version
    header(File.join(ROOT, 'launcher.rb'))['version'].to_s
  end

  def self.date
    header(File.join(ROOT, 'launcher.rb'))['date'].to_s
  end

  def self.tools
    Dir.glob(File.join(ROOT, 'tools', '*', 'main.rb')).sort.map do |f|
      h = header(f)
      h['id'] = File.basename(File.dirname(f))
      h['file'] = f
      h
    end.select { |h| h['name'] && h['module'] }
  end

  def self.new_ids
    JSON.parse(Sketchup.read_default(PREF, 'new', '[]').to_s)
  rescue StandardError
    []
  end

  def self.set_new_ids(list)
    Sketchup.write_default(PREF, 'new', list.uniq.to_json)
  end

  # ---------- chạy tool ----------
  def self.run(id)
    t = tools.find { |x| x['id'] == id }
    return UI.messagebox("Không tìm thấy tool #{id}.") unless t
    mt = File.mtime(t['file']).to_f
    if @loaded[id] != mt
      load t['file']
      @loaded[id] = mt
    end
    mod = t['module'].split('::').inject(Object) { |o, n| o.const_get(n) }
    set_new_ids(new_ids - [id])
    send_list
    mod.show
  rescue StandardError, ScriptError => e
    UI.messagebox("Lỗi khi chạy tool #{id}: #{e.message}")
    puts e.backtrace.first(8).join("\n")
  end

  # ---------- tự cập nhật ----------
  def self.http_get(url, &blk)
    req = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
    begin; req.headers = { 'User-Agent' => 'BoToolSketchUp', 'Cache-Control' => 'no-cache' }; rescue StandardError; end
    @reqs << req
    req.start do |r, res|
      @reqs.delete(r)
      code = res ? res.status_code.to_i : 0
      blk.call(code == 200 ? res.body.to_s : nil)
    end
  rescue StandardError
    blk.call(nil)
  end

  # "1.10.0" > "1.9.2"
  def self.newer?(a, b)
    (a.to_s.split('.').map(&:to_i) <=> b.to_s.split('.').map(&:to_i)) == 1
  end

  # Lấy mã commit mới nhất (bản mới hiện ngay); lỗi thì dùng main (có thể trễ ~5 phút)
  def self.latest_base(&blk)
    http_get("https://api.github.com/repos/#{REPO}/commits/main") do |body|
      sha = nil
      begin; sha = JSON.parse(body)['sha'] if body; rescue StandardError; end
      blk.call("https://raw.githubusercontent.com/#{REPO}/#{sha || 'main'}/")
    end
  end

  # so capnhat.json trên kho với máy: trả về danh sách mục có bản mới
  def self.diff(info)
    items = []
    if newer?(info['version'], version)
      items << { 'name' => 'Bảng Bộ Tool', 'version' => info['version'], 'notes' => info['notes'].to_s, 'id' => '' }
    end
    local = {}
    tools.each { |t| local[t['id']] = t['version'] }
    (info['tools'] || []).each do |t|
      next unless local[t['id']].nil? || newer?(t['version'], local[t['id']])
      items << { 'name' => t['name'], 'version' => t['version'], 'notes' => t['notes'].to_s, 'id' => t['id'],
                 'isNew' => local[t['id']].nil? }
    end
    items
  end

  def self.check_update(quiet)
    js('setChecking(true)')
    latest_base do |base|
      http_get(base + 'capnhat.json') do |body|
        js('setChecking(false)')
        info = nil
        begin; info = JSON.parse(body.dup.force_encoding('UTF-8').sub("﻿", '')) if body; rescue StandardError; end
        if !info
          js("showMsg(#{'Không đọc được thông tin cập nhật (mạng lỗi?). Thử lại sau.'.to_json}, true)") unless quiet
        else
          items = diff(info)
          if items.empty?
            @pending = nil
            js('showUpdate(null)')
            js("showMsg(#{"Đang dùng bản mới nhất (Bộ Tool v#{version}).".to_json}, false)") unless quiet
          else
            info['base'] = base
            info['items'] = items
            @pending = info
            js("showUpdate(#{items.to_json})")
          end
        end
      end
    end
  end

  # tải hết rồi mới ghi đè, xong nạp lại ngay
  def self.do_update
    info = @pending
    return check_update(false) unless info
    files = info['files'] || []
    return js("showMsg(#{'Danh sách file cập nhật trống.'.to_json}, true)") if files.empty?
    plugins = File.dirname(ROOT)
    got = {}
    js("showMsg(#{"Đang tải #{files.size} file…".to_json}, false)")
    files.each do |f|
      url = info['base'] + 'MaNguon/' + f.split('/').map { |x| x.gsub(' ', '%20') }.join('/')
      http_get(url) do |body|
        got[f] = body
        next unless got.size == files.size
        if got.values.any?(&:nil?)
          js("showMsg(#{'Tải không đủ file, chưa đổi gì. Thử lại sau.'.to_json}, true)")
          next
        end
        begin
          files.each do |ff|
            path = File.join(plugins, ff)
            FileUtils.mkdir_p(File.dirname(path))
            File.open(path, 'wb') { |io| io.write(got[ff]) }
          end
        rescue StandardError => e
          js("showMsg(#{"Không ghi được file vào #{plugins}: #{e.message}".to_json}, true)")
          next
        end
        ids = info['items'].map { |i| i['id'] }.reject(&:empty?)
        set_new_ids(new_ids + ids)
        @pending = nil
        @loaded = {} # lần bấm tool sau sẽ nạp code mới
        begin; load File.join(ROOT, 'launcher.rb'); rescue StandardError, ScriptError => e; puts e.message; end
        @dlg.set_file(File.join(ROOT, 'launcher.html')) if @dlg && @dlg.visible?
        UI.messagebox("Đã cập nhật Bộ Tool SketchUp (#{info['items'].map { |i| "#{i['name']} v#{i['version']}" }.join(', ')}).\n" \
                      'Tool đang mở thì đóng hộp thoại tool rồi bấm lại. Nếu thấy lạ, tắt mở lại SketchUp.')
      end
    end
  end

  # ---------- bản cũ cài riêng (Mặt bằng xiên v1.0–1.2) ----------
  def self.disable_old
    old = File.join(File.dirname(ROOT), 'phuc_mat_bang_xien.rb')
    return unless File.exist?(old)
    File.rename(old, old + '.cu')
    UI.messagebox("Đã tắt bản \"Mặt bằng xiên\" cài riêng trước đây, vì tool này giờ nằm trong Bộ Tool SketchUp.\n" \
                  'Tắt mở lại SketchUp một lần cho gọn menu.')
  rescue StandardError
    nil
  end

  # ---------- bảng ----------
  def self.js(code)
    @dlg.execute_script(code) if @dlg && @dlg.visible?
  end

  def self.send_list
    nid = new_ids
    list = tools.map do |t|
      { id: t['id'], name: t['name'], group: t['group'] || 'Khác', desc: t['desc'].to_s, version: t['version'].to_s,
        date: t['date'].to_s, icon: t['icon'].to_s, isNew: nid.include?(t['id']) }
    end
    js("setList(#{{ version: version, date: date, tools: list }.to_json})")
  end

  def self.show
    if @dlg && @dlg.visible?
      @dlg.bring_to_front
      return
    end
    @dlg = UI::HtmlDialog.new(dialog_title: 'Bộ Tool SketchUp', preferences_key: 'PhucBoToolPanel',
                              scrollable: true, resizable: true, width: 340, height: 600,
                              style: UI::HtmlDialog::STYLE_UTILITY)
    @dlg.set_file(File.join(ROOT, 'launcher.html'))
    @dlg.add_action_callback('ready') do |_c, _a|
      send_list
      check_update(true)
    end
    @dlg.add_action_callback('run') { |_c, id| run(id.to_s) }
    @dlg.add_action_callback('check') { |_c, _a| check_update(false) }
    @dlg.add_action_callback('doupdate') { |_c, _a| do_update }
    @dlg.add_action_callback('openfolder') { |_c, _a| UI.openURL('file:///' + File.join(ROOT, 'tools').tr('\\', '/')) }
    @dlg.show
  end

  # khoá cố định (không dùng __FILE__ vì nạp lại sau cập nhật có thể khác dạng đường dẫn)
  unless file_loaded?('phuc_botool/launcher')
    disable_old
    menu = UI.menu('Extensions').add_submenu('Bộ Tool SketchUp (Phúc)')
    menu.add_item('Mở bảng tool') { show }
    menu.add_separator
    tools.each { |t| id = t['id']; menu.add_item(t['name']) { run(id) } }
    cmd = UI::Command.new('Bộ Tool SketchUp') { show }
    icon = File.join(ROOT, 'icon.svg')
    cmd.small_icon = icon
    cmd.large_icon = icon
    cmd.tooltip = 'Bộ Tool SketchUp'
    cmd.status_bar_text = 'Mở bảng Bộ Tool SketchUp: tìm và chạy tool'
    tb = UI::Toolbar.new('Bộ Tool SketchUp')
    tb.add_item(cmd)
    tb.restore
    tb.show if tb.get_last_state != TB_HIDDEN
    file_loaded('phuc_botool/launcher')
  end
end
