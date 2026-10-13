// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package com.tailscale.ipn;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import androidx.work.Data;
import androidx.work.ExistingWorkPolicy;
import androidx.work.OneTimeWorkRequest;
import androidx.work.OutOfQuotaPolicy;
import androidx.work.WorkManager;

import java.util.Objects;

/**
 * IPNReceiver allows external applications to start the VPN.
 *
 * <p>汉化版安全加固：该接收器是导出的（供 Tasker、MacroDroid 等自动化应用使用），
 * 因此只有在设置里打开「允许其他应用控制 VPN」后才会处理 CONNECT/DISCONNECT/USE_EXIT_NODE，
 * 默认关闭时一律忽略。应用自身的通知栏按钮走不导出的 {@link InternalIPNReceiver}，不受此开关影响。
 *
 * <p>上游仅用于集成测试的 com.tailscale.ipn.integration.LOGIN 入口在本分支已彻底移除：
 * 汉化版发布包由 assembleDebug 构建（BuildConfig.DEBUG 为 true），保留它会允许任意应用
 * 用自己的 control_url + auth_key 把设备登录到攻击者的控制服务器。
 */
public class IPNReceiver extends BroadcastReceiver {

    public static final String INTENT_CONNECT_VPN = "com.tailscale.ipn.CONNECT_VPN";
    public static final String INTENT_DISCONNECT_VPN = "com.tailscale.ipn.DISCONNECT_VPN";
    private static final String INTENT_USE_EXIT_NODE = "com.tailscale.ipn.USE_EXIT_NODE";

    // Unique work names prevent connect/disconnect flapping from enqueuing a long backlog.
    private static final String WORK_CONNECT = "ipn-connect-vpn";
    private static final String WORK_DISCONNECT = "ipn-disconnect-vpn";
    private static final String WORK_USE_EXIT_NODE = "ipn-use-exit-node";

    private static final String TAG = "IPNReceiver";

    // 每个进程只记录一次“已忽略外部广播”，避免自动化应用频繁发送时刷屏。
    private static volatile boolean loggedIgnored = false;

    /** 是否跳过“允许其他应用控制 VPN”开关检查。仅不导出的 InternalIPNReceiver 返回 true。 */
    protected boolean isTrustedSender() {
        return false;
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;

        if (!isTrustedSender() && !isExternalControlAllowed()) {
            if (!loggedIgnored) {
                loggedIgnored = true;
                Log.w(TAG, "ignoring external broadcast " + intent.getAction()
                        + ": 「允许其他应用控制 VPN」未开启");
            }
            return;
        }

        handle(context, intent);
    }

    private static boolean isExternalControlAllowed() {
        try {
            return UninitializedApp.get().isExternalVpnControlAllowed();
        } catch (Exception e) {
            // App 实例尚不可用时按关闭处理（失败即拒绝）。
            return false;
        }
    }

    private void handle(Context context, Intent intent) {
        final WorkManager workManager = WorkManager.getInstance(context);
        final String action = intent.getAction();

        if (Objects.equals(action, INTENT_CONNECT_VPN)) {
            OneTimeWorkRequest req =
                    new OneTimeWorkRequest.Builder(StartVPNWorker.class)
                            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                            .addTag(WORK_CONNECT)
                            .build();

            workManager.enqueueUniqueWork(WORK_CONNECT, ExistingWorkPolicy.REPLACE, req);

        } else if (Objects.equals(action, INTENT_DISCONNECT_VPN)) {
            OneTimeWorkRequest req =
                    new OneTimeWorkRequest.Builder(StopVPNWorker.class)
                            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                            .addTag(WORK_DISCONNECT)
                            .build();

            workManager.enqueueUniqueWork(WORK_DISCONNECT, ExistingWorkPolicy.REPLACE, req);

        } else if (Objects.equals(action, INTENT_USE_EXIT_NODE)) {
            String exitNode = intent.getStringExtra("exitNode");
            boolean allowLanAccess = intent.getBooleanExtra("allowLanAccess", false);

            Data input =
                    new Data.Builder()
                            .putString(UseExitNodeWorker.EXIT_NODE_NAME, exitNode)
                            .putBoolean(UseExitNodeWorker.ALLOW_LAN_ACCESS, allowLanAccess)
                            .build();

            OneTimeWorkRequest req =
                    new OneTimeWorkRequest.Builder(UseExitNodeWorker.class)
                            .setInputData(input)
                            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                            .addTag(WORK_USE_EXIT_NODE)
                            .build();

            workManager.enqueueUniqueWork(WORK_USE_EXIT_NODE, ExistingWorkPolicy.REPLACE, req);
        }
    }
}
