"""
GUI关于页面模块

功能：
1. 作为左侧导航的"关于"菜单对应内容页
2. 显示系统版本信息

（本地版已去除远程二维码/加群/赞赏等作者服务内容）
"""
import tkinter as tk

from launcher.gui_theme import COLORS
from launcher.version import CURRENT_VERSION


def render_about_page(app):
    """
    在右侧内容区渲染"关于"页面

    显示版本信息（不加载远程服务器内容）。
    Args:
        app: LauncherApp实例
    """
    content = app._content_frame

    # 滚动容器
    canvas = tk.Canvas(content, bg=COLORS["card_bg"], highlightthickness=0)
    canvas.pack(fill=tk.BOTH, expand=True)
    inner = tk.Frame(canvas, bg=COLORS["card_bg"])
    canvas.create_window((0, 0), window=inner, anchor=tk.NW)
    inner.bind("<Configure>",
               lambda e: canvas.configure(scrollregion=canvas.bbox("all")))

    # 标题
    tk.Label(inner, text="关于", font=("微软雅黑", 14, "bold"),
             fg=COLORS["text"], bg=COLORS["card_bg"]).pack(
        anchor=tk.W, padx=20, pady=(16, 4))

    # 系统名称和版本
    tk.Label(inner, text="ppfish",
             font=("微软雅黑", 12),
             fg=COLORS["text"], bg=COLORS["card_bg"]).pack(
        anchor=tk.W, padx=20)
    tk.Label(inner, text=f"当前版本: v{CURRENT_VERSION}",
             font=("微软雅黑", 10),
             fg=COLORS["text_secondary"], bg=COLORS["card_bg"]).pack(
        anchor=tk.W, padx=20, pady=(0, 8))

    # 分割线
    tk.Frame(inner, height=1, bg=COLORS["border"]).pack(
        fill=tk.X, padx=20, pady=8)

    # 本地版本说明
    tk.Label(inner, text="本地个人测试版本（已去除机器码激活授权与远程服务内容）",
             font=("微软雅黑", 10),
             fg=COLORS["text_secondary"], bg=COLORS["card_bg"]).pack(
        anchor=tk.W, padx=20)
