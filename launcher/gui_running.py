"""
GUI运行状态页面模块

功能：
1. 左侧导航栏：服务状态、Backend日志、WebSocket日志、定时任务日志
2. 右侧内容区：根据选中的菜单显示对应内容
3. 服务状态页：状态指示点、访问地址、操作按钮
4. 日志页：实时日志查看（委托给gui_logs模块）
"""
import threading
import tkinter as tk
import tkinter.messagebox as messagebox

from launcher.gui_theme import COLORS
from launcher.config_store import load_connection_config

# 左侧导航菜单项定义：(标识key, 显示文字)
_NAV_ITEMS = [
    ("dashboard", "仪表盘"),
    ("status", "服务状态"),
    ("log_backend-web", "Backend 日志"),
    ("log_websocket", "WebSocket 日志"),
    ("log_scheduler", "定时任务日志"),
    ("about", "关于"),
]

# 侧边栏配色
_SIDEBAR_BG = "#1e293b"
_SIDEBAR_TEXT = "#94a3b8"
_SIDEBAR_ACTIVE_BG = COLORS["primary"]
_SIDEBAR_ACTIVE_TEXT = "#ffffff"
_SIDEBAR_HOVER_BG = "#334155"


def show_running_page(app, start_results: dict):
    """
    渲染运行状态页面（左右分栏布局）

    Args:
        app: LauncherApp实例
        start_results: 各服务启动结果字典 {key: bool}
    """
    app._clear_page()
    app._current_page = "running"
    app._start_results = start_results
    app._active_sub_page = "dashboard"
    app._nav_labels = {}

    outer = tk.Frame(app.root, bg=COLORS["bg"])
    outer.pack(fill=tk.BOTH, expand=True)

    # ---- 左侧导航栏 ----
    sidebar = tk.Frame(outer, bg=_SIDEBAR_BG, width=160)
    sidebar.pack(side=tk.LEFT, fill=tk.Y)
    sidebar.pack_propagate(False)

    # 导航标题
    tk.Label(sidebar, text="导航菜单", font=("微软雅黑", 10, "bold"),
             fg=_SIDEBAR_ACTIVE_TEXT, bg=_SIDEBAR_BG).pack(pady=(16, 12), padx=14, anchor=tk.W)

    # 导航按钮
    for nav_key, nav_text in _NAV_ITEMS:
        _create_nav_item(app, sidebar, nav_key, nav_text)

    # 底部关闭提示
    tk.Label(sidebar, text="关闭窗口将\n停止所有服务", font=("微软雅黑", 8),
             fg="#475569", bg=_SIDEBAR_BG, justify=tk.CENTER).pack(side=tk.BOTTOM, pady=12)

    # ---- 右侧内容区 ----
    content_frame = tk.Frame(outer, bg=COLORS["card_bg"])
    content_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
    app._content_frame = content_frame

    # 默认显示仪表盘
    _switch_page(app, "dashboard")

    # 启动状态定时刷新
    _auto_refresh(app)


def _create_nav_item(app, sidebar, nav_key: str, nav_text: str):
    """
    创建一个左侧导航菜单项

    Args:
        app: LauncherApp实例
        sidebar: 侧边栏容器
        nav_key: 菜单项标识
        nav_text: 显示文字
    """
    is_active = (nav_key == app._active_sub_page)
    bg = _SIDEBAR_ACTIVE_BG if is_active else _SIDEBAR_BG
    fg = _SIDEBAR_ACTIVE_TEXT if is_active else _SIDEBAR_TEXT

    lbl = tk.Label(sidebar, text=f"  {nav_text}", font=("微软雅黑", 10),
                   fg=fg, bg=bg, anchor=tk.W, padx=14, pady=8, cursor="hand2")
    lbl.pack(fill=tk.X)
    app._nav_labels[nav_key] = lbl

    # 点击事件
    lbl.bind("<Button-1>", lambda e, k=nav_key: _switch_page(app, k))
    # 悬停效果（非活动项）
    lbl.bind("<Enter>", lambda e, l=lbl, k=nav_key:
             l.configure(bg=_SIDEBAR_HOVER_BG) if k != app._active_sub_page else None)
    lbl.bind("<Leave>", lambda e, l=lbl, k=nav_key:
             l.configure(bg=_SIDEBAR_ACTIVE_BG if k == app._active_sub_page else _SIDEBAR_BG))


def _switch_page(app, nav_key: str):
    """
    切换右侧内容区页面

    Args:
        app: LauncherApp实例
        nav_key: 目标菜单项标识
    """
    app._active_sub_page = nav_key

    # 更新导航高亮
    for key, lbl in app._nav_labels.items():
        if key == nav_key:
            lbl.configure(bg=_SIDEBAR_ACTIVE_BG, fg=_SIDEBAR_ACTIVE_TEXT)
        else:
            lbl.configure(bg=_SIDEBAR_BG, fg=_SIDEBAR_TEXT)

    # 清空右侧内容
    for w in app._content_frame.winfo_children():
        w.destroy()

    if nav_key == "dashboard":
        from launcher.gui_dashboard import render_dashboard_page
        render_dashboard_page(app)
    elif nav_key == "status":
        _render_status_content(app)
    elif nav_key == "about":
        from launcher.gui_about import render_about_page
        render_about_page(app)
    elif nav_key.startswith("log_"):
        service_key = nav_key[4:]  # 去掉"log_"前缀
        from launcher.gui_logs import show_log_page
        show_log_page(app, service_key)


def _render_status_content(app):
    """在右侧内容区渲染服务状态页面（直接用端口检测实时状态）"""
    content = app._content_frame
    # 直接用端口检测，不依赖启动结果，避免初始状态不准
    live_status = app.service_manager.get_status()

    # 滚动容器
    canvas = tk.Canvas(content, bg=COLORS["card_bg"], highlightthickness=0)
    canvas.pack(fill=tk.BOTH, expand=True)
    inner = tk.Frame(canvas, bg=COLORS["card_bg"])
    canvas.create_window((0, 0), window=inner, anchor=tk.NW)
    inner.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))

    # 标题
    tk.Label(inner, text="服务状态", font=("微软雅黑", 14, "bold"),
             fg=COLORS["text"], bg=COLORS["card_bg"]).pack(anchor=tk.W, padx=20, pady=(16, 6))

    # 状态列表
    status_frame = tk.Frame(inner, bg=COLORS["card_bg"])
    status_frame.pack(fill=tk.X, padx=20, pady=(0, 10))

    service_names = {
        "backend-web": ("后端管理服务", "8089"),
        "websocket": ("WebSocket服务", "8090"),
        "scheduler": ("定时任务服务", "8091"),
        "frontend": ("前端界面服务", "9000"),
    }

    app._status_labels = {}
    app._status_dots = {}
    errors = app.service_manager.get_errors()

    for key, (display_name, port) in service_names.items():
        row = tk.Frame(status_frame, bg=COLORS["card_bg"])
        row.pack(fill=tk.X, pady=5)

        started = (live_status.get(key) == "运行中")

        # 状态指示点
        dot_color = COLORS["success"] if started else COLORS["error"]
        dot = tk.Canvas(row, width=12, height=12, bg=COLORS["card_bg"], highlightthickness=0)
        dot.pack(side=tk.LEFT, padx=(0, 8), pady=2)
        dot.create_oval(2, 2, 10, 10, fill=dot_color, outline=dot_color)
        app._status_dots[key] = dot

        tk.Label(row, text=display_name, font=("微软雅黑", 10, "bold"),
                 fg=COLORS["text"], bg=COLORS["card_bg"],
                 width=14, anchor=tk.W).pack(side=tk.LEFT)
        tk.Label(row, text=f":{port}", font=("Consolas", 9),
                 fg=COLORS["text_secondary"], bg=COLORS["card_bg"],
                 width=6, anchor=tk.W).pack(side=tk.LEFT)

        status_text = "运行中" if started else "启动失败"
        status_fg = COLORS["success"] if started else COLORS["error"]
        lbl = tk.Label(row, text=status_text, font=("微软雅黑", 10),
                       fg=status_fg, bg=COLORS["card_bg"])
        lbl.pack(side=tk.LEFT, padx=(10, 0))
        app._status_labels[key] = lbl

        if not started and key in errors:
            err_f = tk.Frame(status_frame, bg=COLORS["error_bg"], padx=10, pady=4)
            err_f.pack(fill=tk.X, pady=(0, 2), padx=(20, 0))
            err_text = errors[key][:120] + ("..." if len(errors[key]) > 120 else "")
            tk.Label(err_f, text=f"原因: {err_text}", font=("微软雅黑", 8),
                     fg=COLORS["error"], bg=COLORS["error_bg"],
                     wraplength=450, anchor=tk.W, justify=tk.LEFT).pack(fill=tk.X)

    # 分隔线
    tk.Frame(inner, bg=COLORS["border"], height=1).pack(fill=tk.X, padx=20, pady=8)

    # 访问地址
    tk.Label(inner, text="访问地址", font=("微软雅黑", 11, "bold"),
             fg=COLORS["primary"], bg=COLORS["card_bg"]).pack(anchor=tk.W, padx=20, pady=(0, 4))

    url_frame = tk.Frame(inner, bg=COLORS["card_bg"])
    url_frame.pack(fill=tk.X, padx=20, pady=(0, 8))

    url_lbl = tk.Label(url_frame, text="管理后台：http://127.0.0.1:9000",
                       font=("Consolas", 10), fg=COLORS["accent"],
                       bg=COLORS["card_bg"], cursor="hand2")
    url_lbl.pack(anchor=tk.W)
    url_lbl.bind("<Button-1>", lambda e: open_browser())

    for name, addr in [("后端API", "127.0.0.1:8089"),
                       ("WebSocket", "127.0.0.1:8090"),
                       ("定时任务", "127.0.0.1:8091")]:
        tk.Label(url_frame, text=f"{name}：http://{addr}", font=("Consolas", 9),
                 fg=COLORS["text_secondary"], bg=COLORS["card_bg"]).pack(anchor=tk.W, pady=1)

    # 分隔线
    tk.Frame(inner, bg=COLORS["border"], height=1).pack(fill=tk.X, padx=20, pady=8)

    # 操作按钮
    btn_area = tk.Frame(inner, bg=COLORS["card_bg"])
    btn_area.pack(fill=tk.X, padx=20, pady=(0, 16))

    # 按钮通用配置
    _btn_font = ("微软雅黑", 9)
    _btn_pad = {"padx": 14, "pady": 6}

    # 保存按钮引用，用于禁用/启用反馈
    btn_refresh = tk.Button(
        btn_area, text="🔄 刷新状态", font=_btn_font,
        fg=COLORS["text"], bg="#f1f5f9", activebackground="#e2e8f0",
        bd=0, cursor="hand2", **_btn_pad,
        command=lambda: _on_refresh(app, btn_refresh))
    btn_refresh.pack(side=tk.LEFT, padx=(0, 8))

    tk.Button(
        btn_area, text="🌐 打开管理后台", font=_btn_font,
        fg="#ffffff", bg=COLORS["primary"], activebackground=COLORS["primary_hover"],
        activeforeground="#ffffff", bd=0, cursor="hand2", **_btn_pad,
        command=open_browser).pack(side=tk.LEFT, padx=(0, 8))

    btn_start = tk.Button(
        btn_area, text="▶ 启动所有服务", font=_btn_font,
        fg="#ffffff", bg=COLORS["success"], activebackground="#15803d",
        activeforeground="#ffffff", bd=0, cursor="hand2", **_btn_pad,
        command=lambda: _on_restart(app, btn_start))
    btn_start.pack(side=tk.LEFT, padx=(0, 8))
    app._btn_start = btn_start

    btn_stop = tk.Button(
        btn_area, text="⏹ 停止所有服务", font=_btn_font,
        fg="#ffffff", bg=COLORS["stop_btn"], activebackground=COLORS["stop_hover"],
        activeforeground="#ffffff", bd=0, cursor="hand2", **_btn_pad,
        command=lambda: _on_stop(app, btn_stop))
    btn_stop.pack(side=tk.LEFT, padx=(0, 8))
    app._btn_stop = btn_stop


def _on_refresh(app, btn):
    """刷新按钮点击处理：显示反馈后刷新状态"""
    btn.configure(text="🔄 刷新中...", state=tk.DISABLED)
    app.root.update_idletasks()
    refresh_status(app)
    btn.configure(text="🔄 刷新状态", state=tk.NORMAL)


def _on_restart(app, btn):
    """启动按钮点击处理：禁用按钮并在子线程中重启"""
    btn.configure(text="▶ 启动中...", state=tk.DISABLED)
    if hasattr(app, "_btn_stop"):
        app._btn_stop.configure(state=tk.DISABLED)
    app.root.update_idletasks()
    restart_services(app)


def _on_stop(app, btn):
    """停止按钮点击处理：禁用按钮并停止服务"""
    btn.configure(text="⏹ 停止中...", state=tk.DISABLED)
    if hasattr(app, "_btn_start"):
        app._btn_start.configure(state=tk.DISABLED)
    app.root.update_idletasks()

    def _do_stop():
        stop_services(app)
        app.root.after(0, lambda: _after_stop(app))

    threading.Thread(target=_do_stop, daemon=True).start()


def _after_stop(app):
    """停止完成后恢复按钮状态"""
    if hasattr(app, "_btn_stop"):
        app._btn_stop.configure(text="⏹ 停止所有服务", state=tk.NORMAL)
    if hasattr(app, "_btn_start"):
        app._btn_start.configure(text="▶ 启动所有服务", state=tk.NORMAL)


def refresh_status(app):
    """刷新服务状态，更新状态指示点颜色和文字"""
    if app._current_page != "running":
        return
    if not hasattr(app, "_status_labels"):
        return

    status = app.service_manager.get_status()
    for key, lbl in app._status_labels.items():
        st = status.get(key, "未知")
        if st == "运行中":
            lbl.configure(text="运行中", fg=COLORS["success"])
            if key in app._status_dots:
                d = app._status_dots[key]
                d.delete("all")
                d.create_oval(2, 2, 10, 10, fill=COLORS["success"], outline=COLORS["success"])
        else:
            lbl.configure(text="已停止", fg=COLORS["error"])
            if key in app._status_dots:
                d = app._status_dots[key]
                d.delete("all")
                d.create_oval(2, 2, 10, 10, fill=COLORS["error"], outline=COLORS["error"])


def _auto_refresh(app):
    """每5秒自动刷新服务状态"""
    if app._current_page == "running":
        if getattr(app, "_active_sub_page", "") == "status":
            refresh_status(app)
        app.root.after(5000, lambda: _auto_refresh(app))


def open_browser():
    """在默认浏览器中打开管理后台"""
    import webbrowser
    webbrowser.open("http://127.0.0.1:9000")


def restart_services(app):
    """重新启动所有服务（先停止再启动）"""
    app.service_manager.stop_all()
    config = load_connection_config()
    if not config:
        messagebox.showerror("错误", "未找到已保存的连接配置，请返回配置页面重新填写")
        return
    threading.Thread(target=app._start_services_thread, args=(config,), daemon=True).start()


def stop_services(app):
    """停止所有服务并刷新状态"""
    app.service_manager.stop_all()
    refresh_status(app)
