// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package com.tailscale.ipn;

/**
 * 汉化版：应用自身（通知栏的连接/断开按钮）使用的接收器。
 *
 * <p>在 AndroidManifest 中声明为 exported="false"，其他应用无法向它发送广播，
 * 因此不受「允许其他应用控制 VPN」开关限制，保证通知栏按钮在开关关闭时照常可用。
 */
public class InternalIPNReceiver extends IPNReceiver {
    @Override
    protected boolean isTrustedSender() {
        return true;
    }
}
