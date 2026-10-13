// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package com.tailscale.ipn

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ForegroundInfo
import androidx.work.WorkerParameters
import com.tailscale.ipn.util.TSLog

/**
 * 上游仅供模拟器集成测试使用的 worker：用传入的 control_url + auth_key 登录。
 *
 * 汉化版已禁用：本分支的发布包由 assembleDebug 构建（BuildConfig.DEBUG 恒为 true），
 * 上游“仅调试包可用”的保护在这里无效，任意应用都能借此把设备登录到攻击者的控制服务器。
 * 因此 IPNReceiver 已移除 com.tailscale.ipn.integration.LOGIN 入口，这里也无条件返回失败，
 * 即使被其他途径排入 WorkManager 也不会执行登录。
 */
class IntegrationLoginWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {
  override suspend fun getForegroundInfo(): ForegroundInfo = workerForegroundInfo()

  override suspend fun doWork(): Result {
    TSLog.w(TAG, "integration login is disabled in this build")
    return Result.failure()
  }

  companion object {
    const val TAG = "IntegrationLoginWorker"
    const val WORK_NAME = "ipn-integration-login"
    const val EXTRA_CONTROL_URL = "control_url"
    const val EXTRA_AUTH_KEY = "auth_key"
  }
}
