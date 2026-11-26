# encoding: UTF-8
# @name: Mặt bằng xiên
# @group: Diễn họa
# @desc: Biến mô hình thành ảnh mặt bằng xiên kiểu axonometric: cắt ngang, phần cắt tô màu, nền đen hoặc vẽ tay, xuất PNG.
# @version: 1.4.0
# @date: 2026-11-26
# @icon: layers
# @module: PhucBoTool::MatBangXien
#
# Tool trong Bộ Tool SketchUp (kho nhohoanglux-prog/BoToolSketchUp). Bảng Bộ Tool đọc các dòng @ ở trên.
#
# Cách làm: chép vùng chọn thành 1 group riêng (bản gốc giữ nguyên), "xiên" group đó
# (x' = x + k*cos(g)*(zc - z), y' = y + k*sin(g)*(zc - z)) nên mặt bằng ở cao độ cắt
# giữ phẳng, phần thấp hơn đổ xiên theo góc g. Trong group đặt 1 mặt cắt ngang ở zc,
# camera song song nhìn thẳng từ trên, đổi kiểu hiển thị (nền, nét, tô phần cắt), xuất PNG.
require 'json'

module PhucBoTool
  module MatBangXien
    DICT = 'phuc_mbx'.freeze
    PREF = 'PhucMatBangXien'.freeze
    IN_PER_M = 39.37007874015748
    RO_KEYS = %w[RenderMode BackgroundColor ForegroundColor EdgeColorMode DrawSilhouettes SilhouetteWidth
                 DrawDepthQue DepthQueWidth DrawGround DrawHorizon DisplaySectionPlanes DisplaySectionCuts
                 SectionCutWidth SectionDefaultCutColor SectionCutFilled SectionDefaultFillColor DisplayFog
                 FogUseBkColor FogColor DisplaySketchAxes DrawLineEnds ExtendLines JitterEdges
                 HideConstructionGeometry DisplayWatermarks].freeze

    @dlg = nil
    @saved = nil # trạng thái trước khi dựng (kiểu hiển thị, camera, mặt cắt đang bật)

    def self.model
      Sketchup.active_model
    end

    # ---------- tiện ích ----------
    def self.color(hex)
      h = hex.to_s.sub('#', '')
      h = 'ffffff' unless h =~ /\A[0-9a-fA-F]{6}\z/
      Sketchup::Color.new(h[0, 2].to_i(16), h[2, 2].to_i(16), h[4, 2].to_i(16))
    end

    def self.num(v, default)
      s = v.to_s.strip.tr(',', '.')
      s.empty? ? default : s.to_f
    end

    def self.m(inches)
      (inches.to_f / IN_PER_M).round(2)
    end

    # "1,2; 4.8" -> [1.2, 4.8]
    def self.heights(p)
      list = p['height'].to_s.split(/[;\n]+/).map { |t| t.strip.tr(',', '.') }.reject(&:empty?).map(&:to_f)
      list.empty? ? [1.2] : list
    end

    def self.find_copy
      model.entities.grep(Sketchup::Group).find { |g| g.valid? && g.get_attribute(DICT, 'copy') }
    end

    def self.section_of(copy)
      copy.entities.grep(Sketchup::SectionPlane).find { |s| s.get_attribute(DICT, 'cut') }
    end

    def self.source_entities
      sel = model.selection.to_a
      sel = model.active_entities.to_a if sel.empty?
      sel.select do |e|
        e.is_a?(Sketchup::Drawingelement) && !e.is_a?(Sketchup::SectionPlane) &&
          !(e.is_a?(Sketchup::Group) && e.get_attribute(DICT, 'copy'))
      end
    end

    def self.bounds_of(list)
      bb = Geom::BoundingBox.new
      list.each { |e| bb.add(e.bounds) if e.respond_to?(:bounds) }
      bb
    end

    # cao độ cắt (inch, toạ độ mô hình) của 1 giá trị mét
    def self.cut_z(p, h_m, bb_src)
      base = p['ref'] == 'zero' ? 0.0 : bb_src.min.z.to_f
      base + h_m * IN_PER_M
    end

    # hướng đổ xiên trên màn hình (nhìn từ trên, trục Y hướng lên)
    def self.direction(p)
      a = num(p['angle'], 45.0)
      t = case p['dir']
          when 'xt' then -(180.0 - a)  # xuống trái
          when 'lp' then a             # lên phải
          when 'lt' then 180.0 - a     # lên trái
          when 'xd' then -90.0         # thẳng xuống (plan oblique cổ điển, hay đi kèm xoay mặt bằng 45°)
          else -a                      # xuống phải (như ref)
          end
      k = num(p['length'], 100.0) / 100.0
      r = t * Math::PI / 180.0
      [Math.cos(r) * k, Math.sin(r) * k]
    end

    def self.shear(p, zc, ox)
      dx, dy = direction(p)
      Geom::Transformation.new([1, 0, 0, 0,
                                0, 1, 0, 0,
                                -dx, -dy, 1, 0,
                                dx * zc + ox, dy * zc, 0, 1])
    end

    def self.save_state
      return if @saved
      ro = model.rendering_options
      vals = {}
      RO_KEYS.each { |k| begin; vals[k] = ro[k]; rescue StandardError; end }
      c = model.active_view.camera
      cam = { eye: c.eye, target: c.target, up: c.up, persp: c.perspective? }
      cam[:fov] = c.fov if c.perspective?
      cam[:height] = c.height unless c.perspective?
      sp = nil
      begin; sp = model.entities.active_section_plane; rescue StandardError; end
      @saved = { ro: vals, cam: cam, sp: sp }
    end

    # ---------- kiểu hiển thị ----------
    def self.apply_style(p)
      save_state
      ro = model.rendering_options
      set = lambda { |k, v| begin; ro[k] = v; rescue StandardError; end }
      set.call('RenderMode', p['mode'].to_i == 2 ? 2 : 1) # 1 = Hidden Line: mặt tô bằng màu nền
      set.call('BackgroundColor', color(p['bg']))
      set.call('ForegroundColor', color(p['line']))
      set.call('EdgeColorMode', 0) # mọi nét cùng 1 màu
      prof = p['profile'].to_i
      set.call('DrawSilhouettes', prof > 0)
      set.call('SilhouetteWidth', [prof, 1].max)
      dq = p['depth'].to_i
      set.call('DrawDepthQue', dq > 1)
      set.call('DepthQueWidth', [dq, 2].max)
      set.call('DrawGround', false)
      set.call('DrawHorizon', false)
      set.call('DisplaySectionPlanes', false)
      set.call('DisplaySectionCuts', true)
      set.call('SectionCutWidth', [p['cutw'].to_i, 1].max)
      set.call('SectionDefaultCutColor', color(p['cut']))
      set.call('SectionCutFilled', p['fillOn'] ? true : false)
      set.call('SectionDefaultFillColor', color(p['fill']))
      set.call('DisplayFog', p['fog'] ? true : false)
      set.call('FogUseBkColor', true)
      set.call('DisplaySketchAxes', false)
      set.call('DrawLineEnds', false)
      set.call('ExtendLines', false)
      set.call('JitterEdges', false)
      set.call('HideConstructionGeometry', true)
      model.active_view.invalidate
    end

    # ---------- camera ----------
    def self.frame(copy)
      view = model.active_view
      bb = copy.bounds
      c = bb.center
      eye = Geom::Point3d.new(c.x, c.y, bb.max.z + bb.diagonal * 2 + 100)
      cam = Sketchup::Camera.new(eye, c, Geom::Vector3d.new(0, 1, 0))
      cam.perspective = false
      view.camera = cam
      view.zoom(copy)
      cam = view.camera
      cam.height = cam.height * 1.06
      view.camera = cam
      view.invalidate
    end

    # ---------- dựng / cập nhật ----------
    def self.build(p)
      if model.active_path && !model.active_path.empty?
        return err('Bạn đang ở trong một group/component. Bấm ra ngoài (thoát khỏi group) rồi bấm Dựng lại.')
      end
      src = source_entities
      return err('Không có gì để dựng. Chọn các khối muốn dựng (hoặc bỏ chọn hết để dựng cả mô hình).') if src.empty?
      save_state
      model.start_operation('Dựng mặt bằng xiên', true)
      begin
        old = find_copy
        old.erase! if old
        begin; model.entities.active_section_plane = nil; rescue StandardError; end
        bb = bounds_of(src)
        tmp = model.entities.add_group(src)
        copy = tmp.copy
        tmp.explode
        copy.make_unique
        copy.name = 'Mặt bằng xiên'
        copy.set_attribute(DICT, 'copy', true)
        copy.set_attribute(DICT, 'zmin', bb.min.z.to_f)
        copy.set_attribute(DICT, 'zmax', bb.max.z.to_f)
        diag = bb.diagonal.to_f
        copy.set_attribute(DICT, 'ox', bb.width.to_f + bb.depth.to_f + diag * 2)
        copy.set_attribute(DICT, 'cx', bb.center.x.to_f)
        copy.set_attribute(DICT, 'cy', bb.center.y.to_f)
        sp = copy.entities.add_section_plane([Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, -1)])
        sp.set_attribute(DICT, 'cut', true)
        place(copy, p, heights(p)[0])
        model.commit_operation
      rescue StandardError => e
        model.abort_operation
        return err("Lỗi khi dựng: #{e.message}")
      end
      model.selection.clear
      apply_style(p)
      frame(find_copy)
      send_info
      msg("Đã dựng xong (bản gốc vẫn nguyên, bản xiên nằm bên phải). Ctrl+Z để bỏ.")
    end

    # đặt độ xiên + mặt cắt cho cao độ h (mét)
    def self.place(copy, p, h_m)
      zmin = copy.get_attribute(DICT, 'zmin').to_f
      zmax = copy.get_attribute(DICT, 'zmax').to_f
      bb = Geom::BoundingBox.new
      bb.add(Geom::Point3d.new(0, 0, zmin))
      cut = p['cutOn'] != false
      zc = cut ? cut_z(p, h_m, bb) : zmax
      # xiên quanh đáy (zmin) nên đổi cao độ cắt không làm hình dịch chỗ (xuất nhiều cao độ khớp nhau)
      ox = copy.get_attribute(DICT, 'ox').to_f
      tr = shear(p, zmin, ox)
      rot = num(p['rot'], 0.0)
      if rot.abs > 0.001
        cx = copy.get_attribute(DICT, 'cx').to_f
        cy = copy.get_attribute(DICT, 'cy').to_f
        tr = tr * Geom::Transformation.rotation(Geom::Point3d.new(cx, cy, 0), Z_AXIS, rot * Math::PI / 180.0)
      end
      copy.transformation = tr
      sp = section_of(copy)
      if sp
        n = p['flip'] ? 1 : -1
        sp.set_plane([Geom::Point3d.new(0, 0, zc), Geom::Vector3d.new(0, 0, n)])
        if cut
          sp.activate
        else
          begin; copy.entities.active_section_plane = nil; rescue StandardError; end
        end
      end
      zc
    end

    def self.update(p, reframe = true)
      copy = find_copy
      return build(p) unless copy
      model.start_operation('Cập nhật mặt bằng xiên', true, false, true)
      place(copy, p, heights(p)[0])
      model.commit_operation
      apply_style(p)
      frame(copy) if reframe
    end

    # ---------- xuất PNG ----------
    # fmt = 'png' (ảnh) hoặc 'pdf' (vector: nét giữ mảnh khi phóng to, độ dày tính bằng mm)
    def self.export(p, fmt = 'png')
      copy = find_copy
      return err('Chưa có mặt bằng xiên. Bấm "Dựng mặt bằng xiên" trước.') unless copy
      dir = model.path.to_s.empty? ? File.join(ENV['USERPROFILE'] || Dir.home, 'Desktop') : File.dirname(model.path)
      base = model.title.to_s.empty? ? 'MatBangXien' : "#{model.title}_MatBangXien"
      ext = fmt == 'pdf' ? 'pdf' : 'png'
      path = UI.savepanel(fmt == 'pdf' ? 'Lưu file PDF' : 'Lưu ảnh PNG', dir, "#{base}.#{ext}")
      return unless path
      path += ".#{ext}" unless path =~ /\.#{ext}\z/i
      view = model.active_view
      w = [p['width'].to_i, 500].max
      h = (w * view.vpheight.to_f / view.vpwidth.to_f).round
      hs = p['cutOn'] == false ? [heights(p)[0]] : heights(p)
      files = []
      hs.each do |hm|
        model.start_operation('Xuất mặt bằng xiên', true, false, true)
        place(copy, p, hm)
        model.commit_operation
        view.invalidate
        f = hs.size > 1 ? path.sub(/\.#{ext}\z/i, format("_cat%.2fm.#{ext}", hm).sub('.', ',')) : path
        ok = fmt == 'pdf' ? write_pdf(f, p) : write_png(view, f, w, h, p)
        files << f if ok
      end
      if hs.size > 1
        model.start_operation('Cập nhật mặt bằng xiên', true, false, true)
        place(copy, p, hs[0])
        model.commit_operation
      end
      if files.empty?
        return err('Không xuất được PDF. Bản SketchUp Make (miễn phí) không có xuất PDF; thử xuất PNG.') if fmt == 'pdf'
        return err('Không xuất được ảnh. Thử chiều ngang nhỏ hơn (ví dụ 4000 px).')
      end
      size = fmt == 'pdf' ? 'PDF vector' : "#{w} x #{h} px"
      r = UI.messagebox("Đã xuất #{files.size} file (#{size}):\n#{files.join("\n")}\n\nMở thư mục chứa ảnh?", MB_YESNO)
      UI.openURL('file:///' + File.dirname(files[0]).tr('\\', '/')) if r == IDYES
    end

    # PNG: scale_factor = hệ số nhân độ dày nét/chữ khi ảnh lớn hơn màn hình (SketchUp 2019.2+ mặc định 2 → nét dày).
    # 1 = nét mảnh nhất. Khoá lạ bị SketchUp bỏ qua; lỗi thì xuất lại không có khoá đó.
    def self.write_png(view, f, w, h, p)
      sf = num(p['lineScale'], 1.0)
      opts = { filename: f, width: w, height: h, antialias: true, transparent: false, compression: 0.9 }
      begin
        view.write_image(opts.merge(scale_factor: sf))
      rescue StandardError
        view.write_image(opts)
      end
    end

    # PDF vector (SketchUp Pro, Windows). Độ dày nét theo mm, không theo màn hình (match_screen_* = false).
    # Khoá theo tài liệu "Exporter Options" của SketchUp; số phải là Float, khoá sai bị bỏ qua. CHƯA kiểm chứng.
    def self.write_pdf(f, p)
      mm = ->(v, d) { num(v, d) / 25.4 } # SketchUp tính độ dày theo inch
      opts = {
        output_profile_lines: true, output_section_lines: true, edge_extensions: false,
        match_screen_profiles: false, match_screen_section: false, match_screen_extensions: false,
        line_width: mm.call(p['pdfLine'], 0.05).to_f, line_width_section: mm.call(p['pdfCut'], 0.25).to_f,
        full_scale: false, map_fonts: true, extension_length: 0.0
      }
      model.export(f, opts)
    rescue StandardError => e
      puts "PDF: #{e.message}"
      false
    end

    # ---------- chọn cao độ ----------
    class PickTool
      def initialize(&blk)
        @ip = Sketchup::InputPoint.new
        @blk = blk
      end

      def activate
        Sketchup.status_text = 'Bấm vào một điểm trên mô hình để lấy cao độ cắt (Esc để thôi). Nên xoay mô hình để thấy cạnh tường.'
      end

      def onMouseMove(_flags, x, y, view)
        @ip.pick(view, x, y)
        if @ip.valid?
          view.tooltip = "Cao độ: #{MatBangXien.m(@ip.position.z)} m"
          Sketchup.vcb_label = 'Cao độ (m)'
          Sketchup.vcb_value = MatBangXien.m(@ip.position.z).to_s
        end
        view.invalidate
      end

      def draw(view)
        @ip.draw(view) if @ip.valid?
      end

      def onLButtonDown(_flags, x, y, view)
        @ip.pick(view, x, y)
        return unless @ip.valid?
        @blk.call(@ip.position.z.to_f)
        Sketchup.active_model.select_tool(nil)
      end

      def onCancel(_reason, _view)
        Sketchup.active_model.select_tool(nil)
      end
    end

    def self.height_from_z(z, p)
      return m(z) if p['ref'] == 'zero'
      c = find_copy
      return m(z - c.get_attribute(DICT, 'zmin').to_f) if c
      bb = bounds_of(source_entities)
      m(bb.empty? ? z : z - bb.min.z.to_f)
    end

    def self.pick(p)
      model.select_tool(PickTool.new { |z| js("setHeight(#{height_from_z(z, p)})") })
    end

    def self.from_section(p)
      sp = nil
      begin; sp = model.entities.active_section_plane; rescue StandardError; end
      sp ||= (@saved && @saved[:sp] && @saved[:sp].valid? ? @saved[:sp] : nil)
      sp ||= model.entities.grep(Sketchup::SectionPlane).first
      return err('Không thấy mặt cắt nào trong mô hình (ngoài cùng).') unless sp
      a, b, c, d = sp.get_plane
      return err('Mặt cắt đang có không nằm ngang.') if c.abs < 0.999
      js("setHeight(#{height_from_z(-d / c, p)})")
    end

    # ---------- trả lại như cũ ----------
    def self.restore
      model.start_operation('Bỏ mặt bằng xiên', true)
      c = find_copy
      c.erase! if c
      model.commit_operation
      if @saved
        ro = model.rendering_options
        @saved[:ro].each { |k, v| begin; ro[k] = v; rescue StandardError; end }
        s = @saved[:cam]
        cam = Sketchup::Camera.new(s[:eye], s[:target], s[:up])
        cam.perspective = s[:persp]
        cam.fov = s[:fov] if s[:persp] && s[:fov]
        cam.height = s[:height] if !s[:persp] && s[:height]
        model.active_view.camera = cam
        begin; @saved[:sp].activate if @saved[:sp] && @saved[:sp].valid?; rescue StandardError; end
        @saved = nil
      end
      model.active_view.invalidate
      send_info
      msg('Đã xoá bản xiên và trả kiểu hiển thị, góc nhìn như cũ.')
    end

    # phiên bản đọc từ dòng @version ở đầu file (cập nhật xong nạp lại là thấy số mới)
    def self.version
      File.read(__FILE__, encoding: 'UTF-8')[/@version:\s*(\S+)/, 1].to_s
    end

    def self.date
      File.read(__FILE__, encoding: 'UTF-8')[/@date:\s*(\S+)/, 1].to_s
    end

    # ---------- hộp thoại ----------
    def self.js(code)
      @dlg.execute_script(code) if @dlg && @dlg.visible?
    end

    def self.msg(t)
      js("showMsg(#{t.to_json}, false)")
    end

    def self.err(t)
      if @dlg && @dlg.visible?
        js("showMsg(#{t.to_json}, true)")
      else
        UI.messagebox(t)
      end
      nil
    end

    def self.send_info
      src = source_entities
      bb = bounds_of(src)
      selected = !model.selection.empty?
      info = {
        version: version, date: date,
        count: src.size, selected: selected,
        zmin: bb.empty? ? 0 : m(bb.min.z), zmax: bb.empty? ? 0 : m(bb.max.z),
        built: !find_copy.nil?
      }
      js("setInfo(#{info.to_json})")
    end

    def self.prefs
      Sketchup.read_default(PREF, 'params', '')
    end

    def self.safe(p_json)
      p = p_json.to_s.empty? ? {} : JSON.parse(p_json.to_s)
      Sketchup.write_default(PREF, 'params', p_json.to_s) unless p.empty?
      yield p
    rescue StandardError => e
      err("Có lỗi: #{e.message}")
      puts e.backtrace.first(5).join("\n")
    end

    def self.show
      if @dlg && @dlg.visible?
        @dlg.bring_to_front
        return
      end
      @dlg = UI::HtmlDialog.new(dialog_title: "Mặt bằng xiên v#{version}", preferences_key: 'PhucMatBangXienDlg',
                                scrollable: true, resizable: true, width: 430, height: 820,
                                style: UI::HtmlDialog::STYLE_DIALOG)
      @dlg.set_file(File.join(__dir__, 'dialog.html'))
      @dlg.add_action_callback('ready') do |_c, _a|
        js("init(#{prefs.to_s.empty? ? 'null' : prefs})")
        send_info
      end
      @dlg.add_action_callback('tools') { |_c, _a| PhucBoTool.show if PhucBoTool.respond_to?(:show) }
      @dlg.add_action_callback('info') { |_c, _a| send_info }
      @dlg.add_action_callback('build') { |_c, a| safe(a) { |p| build(p) } }
      @dlg.add_action_callback('update') { |_c, a| safe(a) { |p| update(p) if find_copy } }
      @dlg.add_action_callback('style') { |_c, a| safe(a) { |p| apply_style(p) } }
      @dlg.add_action_callback('frame') { |_c, a| safe(a) { |_p| c = find_copy; c ? frame(c) : err('Chưa có mặt bằng xiên.') } }
      @dlg.add_action_callback('export') { |_c, a| safe(a) { |p| export(p, 'png') } }
      @dlg.add_action_callback('exportpdf') { |_c, a| safe(a) { |p| export(p, 'pdf') } }
      @dlg.add_action_callback('pick') { |_c, a| safe(a) { |p| pick(p) } }
      @dlg.add_action_callback('fromsp') { |_c, a| safe(a) { |p| from_section(p) } }
      @dlg.add_action_callback('restore') { |_c, _a| begin; restore; rescue StandardError => e; err("Có lỗi: #{e.message}"); end }
      @dlg.show
    end
  end
end
