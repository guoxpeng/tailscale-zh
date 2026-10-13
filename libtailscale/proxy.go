// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

// Proxy controller - exposes proxy server functions for Java/Kotlin

package libtailscale

import (
	"fmt"
	"log"
	"sync"
)

var (
	globalProxy     *ProxyServer
	globalProxyLock sync.Mutex
)

// StartProxy starts the tsnet-based proxy server.
// Called from Java/Kotlin via gomobile.
func StartProxy(dataDir string, hostname string, socksPort int, httpPort int) error {
	globalProxyLock.Lock()
	defer globalProxyLock.Unlock()

	if globalProxy != nil && globalProxy.IsRunning() {
		return fmt.Errorf("proxy already running")
	}

	log.Printf("Starting proxy: dataDir=%s hostname=%s socks=%d http=%d", 
		dataDir, hostname, socksPort, httpPort)

	globalProxy = NewProxyServer(dataDir, hostname, socksPort, httpPort)
	
	if err := globalProxy.Start(); err != nil {
		globalProxy = nil
		return fmt.Errorf("start proxy: %w", err)
	}

	return nil
}

// StopProxy stops the proxy server.
func StopProxy() {
	globalProxyLock.Lock()
	defer globalProxyLock.Unlock()

	if globalProxy != nil {
		log.Printf("Stopping proxy")
		globalProxy.Stop()
		globalProxy = nil
	}
}

// IsProxyRunning returns whether the proxy is running.
//
// 不能拿 globalProxyLock：StartProxy 在等待 tsnet 进入 Running 时会持锁最长 60 秒，
// 而 App.startVPN() 在主线程上调用本函数，持锁会让「打开 VPN」卡住主线程直至 ANR。
// activeProxy 只在代理真正启动成功后才被设置、Stop 时清空，语义与原来一致。
func IsProxyRunning() bool {
	return activeProxy.Load() != nil
}

// GetProxyAuthURL returns the auth URL if login is needed.
func GetProxyAuthURL() string {
	globalProxyLock.Lock()
	defer globalProxyLock.Unlock()
	if globalProxy == nil {
		return ""
	}
	return globalProxy.GetAuthURL()
}

// GetProxyIPs returns the Tailscale IPs assigned to this proxy node.
func GetProxyIPs() string {
	globalProxyLock.Lock()
	defer globalProxyLock.Unlock()
	if globalProxy == nil {
		return ""
	}
	ips := globalProxy.GetIPs()
	if len(ips) == 0 {
		return ""
	}
	result := ""
	for i, ip := range ips {
		if i > 0 {
			result += ","
		}
		result += ip
	}
	return result
}

// GetProxyPeers returns the list of peers in the tailnet.
func GetProxyPeers() string {
	globalProxyLock.Lock()
	defer globalProxyLock.Unlock()
	if globalProxy == nil {
		return "[]"
	}
	return globalProxy.GetPeers()
}
