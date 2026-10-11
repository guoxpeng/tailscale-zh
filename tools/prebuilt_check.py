#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""校验仓库里「可直接下载的成品副本」与本次构建是否一致。

背景（2026-10-11 发现的一处真实漂移）：
    README 的「方式 B：手动替换」和「方式 C：一键脚本」都让用户去仓库里下载
        prebuilt/tailscale-ipn.zh.exe
        scripts/install_zh.bat
    可这两个文件是**手工提交**进仓库的，CI 从不过问它们。
    结果对照表从 126 条加到 140 条（补引导页/登录页汉化）之后，
    `build/` 里的产物换了，`prebuilt/` 里那份**还是 126 条的老版本** ——
    用户按方式 B/C 装出来，主界面仍然是英文，而且 `SHA256SUMS.txt`
    记录的还是旧哈希，看起来「校验通过」，无从发现。
    docs/patch-report.txt（README 里说的「最近一次补丁明细」）同样漂移了。

    现在把这件事变成 CI 的硬检查：每次构建都要求
        prebuilt/tailscale-ipn.zh.exe  与本次 build 的产物**逐字节一致**
        prebuilt/SHA256SUMS.txt        里每一条哈希都与实际文件吻合
    不一致就让 CI 直接失败，逼着提交者当场刷新。

用法：
    python tools/prebuilt_check.py <刚构建出的 tailscale-ipn.zh.exe>
    python tools/prebuilt_check.py <刚构建出的 tailscale-ipn.zh.exe> --fix
        --fix 会顺手把 prebuilt/ 与 SHA256SUMS.txt 刷新到当前状态
        （提交前跑一次即可）。
"""
import hashlib
import io
import os
import shutil
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (仓库内相对路径, 清单里写的文件名)
#   清单里用 basename —— 用户是把这几份文件下到同一个文件夹里再跑脚本的，
#   写成带目录的相对路径反而对不上。
ENTRIES = [
    ("prebuilt/tailscale-ipn.zh.exe", "tailscale-ipn.zh.exe"),
    ("scripts/install_zh.bat", "install_zh.bat"),
]
SUMS = os.path.join(REPO, "prebuilt", "SHA256SUMS.txt")
PREBUILT_EXE = os.path.join(REPO, "prebuilt", "tailscale-ipn.zh.exe")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_sums():
    """-> {文件名: 哈希}；顺带返回原始行，便于原样判断。"""
    if not os.path.isfile(SUMS):
        return None
    d = {}
    for ln in io.open(SUMS, encoding="utf-8").read().splitlines():
        s = ln.strip()
        if not s or s.startswith("#"):
            continue
        parts = s.split(None, 1)
        if len(parts) != 2:
            return None
        d[parts[1].strip().lstrip("*")] = parts[0].lower()
    return d


def write_sums():
    lines = []
    for rel, name in sorted(ENTRIES, key=lambda x: x[1]):
        p = os.path.join(REPO, rel)
        lines.append("%s  %s" % (sha256(p), name))
    io.open(SUMS, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2

    built = os.path.abspath(argv[1])
    fix = "--fix" in argv[2:]

    if not os.path.isfile(built):
        print("ERROR: 找不到刚构建出的产物: %s" % built, file=sys.stderr)
        return 2

    bad = []

    # 1) prebuilt 的 exe 必须与本次构建逐字节一致
    built_hash = sha256(built)
    if not os.path.isfile(PREBUILT_EXE):
        bad.append("prebuilt/tailscale-ipn.zh.exe 不存在")
        pre_hash = None
    else:
        pre_hash = sha256(PREBUILT_EXE)
        if pre_hash != built_hash:
            bad.append(
                "prebuilt/tailscale-ipn.zh.exe 与本次构建不一致\n"
                "    prebuilt : %s\n"
                "    本次构建 : %s" % (pre_hash, built_hash))

    # 2) SHA256SUMS.txt 必须与磁盘上的文件吻合，且条目齐备
    sums = read_sums()
    if sums is None:
        bad.append("prebuilt/SHA256SUMS.txt 缺失或格式不正确")
    else:
        want_names = set(n for _, n in ENTRIES)
        if set(sums) != want_names:
            bad.append("SHA256SUMS.txt 的条目不对: 实际 %s / 期望 %s"
                       % (sorted(sums), sorted(want_names)))
        for rel, name in ENTRIES:
            p = os.path.join(REPO, rel)
            if not os.path.isfile(p):
                bad.append("%s 不存在" % rel)
                continue
            real = sha256(p)
            got = sums.get(name)
            if got is not None and got != real:
                bad.append("SHA256SUMS.txt 里 %s 的哈希过期\n"
                           "    清单 : %s\n"
                           "    实际 : %s" % (name, got, real))

    if not bad:
        print("OK: prebuilt 与本次构建一致（%s）" % built_hash)
        print("OK: SHA256SUMS.txt 校验通过（%d 条）" % len(ENTRIES))
        return 0

    print("== 发现 %d 处不一致 ==" % len(bad))
    for b in bad:
        print("  - " + b)

    if not fix:
        print("\n提交前请跑一次以刷新：python tools/prebuilt_check.py "
              "<刚构建出的 exe> --fix")
        return 1

    print("\n--fix：正在把 prebuilt/ 与 SHA256SUMS.txt 刷新到当前状态 …")
    os.makedirs(os.path.dirname(PREBUILT_EXE), exist_ok=True)
    shutil.copyfile(built, PREBUILT_EXE)
    write_sums()
    report_src = os.path.join(REPO, "build", "patch-report.txt")
    if os.path.isfile(report_src):
        shutil.copyfile(report_src, os.path.join(REPO, "docs", "patch-report.txt"))
        print("  已刷新 docs/patch-report.txt")
    print("  已刷新 prebuilt/tailscale-ipn.zh.exe -> %s" % sha256(PREBUILT_EXE))
    print("  已刷新 prebuilt/SHA256SUMS.txt")
    print("请把这三个文件一起提交，否则 CI 仍会因 prebuilt 与构建不一致而失败。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
