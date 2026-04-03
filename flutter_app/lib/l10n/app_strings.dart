import 'dart:ui';

class AppStrings {
  AppStrings._();

  static bool get _isChinese =>
      PlatformDispatcher.instance.locale.languageCode == 'zh';

  static bool get isChinese => _isChinese;

  static String get appName => 'OpenClaw';
  static String get cancel => _isChinese ? '取消' : 'Cancel';
  static String get retry => _isChinese ? '重试' : 'Retry';
  static String get remove => _isChinese ? '移除' : 'Remove';
  static String get done => _isChinese ? '完成' : 'Done';
  static String get install => _isChinese ? '安装' : 'Install';
  static String get loading => _isChinese ? '加载中...' : 'Loading...';
  static String get copy => _isChinese ? '复制' : 'Copy';
  static String get paste => _isChinese ? '粘贴' : 'Paste';
  static String get openUrl => _isChinese ? '打开链接' : 'Open URL';
  static String get screenshot => _isChinese ? '截图' : 'Screenshot';
  static String get restart => _isChinese ? '重启' : 'Restart';
  static String get later => _isChinese ? '稍后' : 'Later';
  static String get download => _isChinese ? '下载' : 'Download';
  static String get copied => _isChinese ? '已复制到剪贴板' : 'Copied to clipboard';
  static String get noUrlFound =>
      _isChinese ? '未找到链接' : 'No URL found in selection';
  static String get linkCopied => _isChinese ? '链接已复制' : 'Link copied';

  static String get aiGatewayForAndroid =>
      _isChinese ? 'Android AI 网关' : 'AI Gateway for Android';
  static String get checkingSetup =>
      _isChinese ? '检查安装状态...' : 'Checking setup status...';
  static String get repairingBypass =>
      _isChinese ? '修复 Bionic Bypass...' : 'Repairing bionic bypass...';
  static String get reinstallingNode =>
      _isChinese ? '重新安装 Node.js...' : 'Reinstalling Node.js...';
  static String get reinstallingOpenClaw =>
      _isChinese ? '重新安装 OpenClaw...' : 'Reinstalling OpenClaw...';

  static String get quickActions => _isChinese ? '快捷操作' : 'QUICK ACTIONS';
  static String get terminal => _isChinese ? '终端' : 'Terminal';
  static String get terminalSubtitle =>
      _isChinese ? '打开 Ubuntu Shell' : 'Open Ubuntu shell with OpenClaw';
  static String get webDashboard => _isChinese ? 'Web 控制台' : 'Web Dashboard';
  static String get webDashboardSubtitle => _isChinese
      ? '在浏览器中打开 OpenClaw 控制台'
      : 'Open OpenClaw dashboard in browser';
  static String get startGatewayFirst =>
      _isChinese ? '请先启动网关' : 'Start gateway first';
  static String get onboarding => _isChinese ? '初始配置' : 'Onboarding';
  static String get onboardingSubtitle =>
      _isChinese ? '配置 API 密钥和绑定设置' : 'Configure API keys and binding';
  static String get configure => _isChinese ? '网关配置' : 'Configure';
  static String get configureSubtitle =>
      _isChinese ? '管理网关设置' : 'Manage gateway settings';
  static String get aiProviders => _isChinese ? 'AI 提供商' : 'AI Providers';
  static String get aiProvidersSubtitle =>
      _isChinese ? '配置模型和 API 密钥' : 'Configure models and API keys';
  static String get packages => _isChinese ? '扩展包' : 'Packages';
  static String get packagesSubtitle => _isChinese
      ? '安装可选工具 (Go, Homebrew, SSH)'
      : 'Install optional tools (Go, Homebrew, SSH)';
  static String get sshAccess => _isChinese ? 'SSH 访问' : 'SSH Access';
  static String get sshAccessSubtitle =>
      _isChinese ? '通过 SSH 远程访问终端' : 'Remote terminal access via SSH';
  static String get logs => _isChinese ? '日志' : 'Logs';
  static String get logsSubtitle =>
      _isChinese ? '查看网关输出和错误' : 'View gateway output and errors';
  static String get snapshot => _isChinese ? '快照' : 'Snapshot';
  static String get snapshotSubtitle =>
      _isChinese ? '备份或恢复配置' : 'Backup or restore your config';
  static String get node => _isChinese ? '节点' : 'Node';
  static String get nodeConnected =>
      _isChinese ? '已连接到网关' : 'Connected to gateway';
  static String get nodeCapabilities =>
      _isChinese ? '为 AI 提供设备能力' : 'Device capabilities for AI';
  static String get dashboardUrlCopied =>
      _isChinese ? '控制台链接已复制' : 'Dashboard URL copied';
  static String get copyDashboardUrl =>
      _isChinese ? '复制控制台链接' : 'Copy dashboard URL';
  static String get cliProxy => _isChinese ? 'CLIProxy 管理' : 'CLIProxy Manager';
  static String get cliProxySubtitle =>
      _isChinese ? '管理免费 AI 账号代理' : 'Manage free AI account proxy';

  static String get gateway => _isChinese ? '网关' : 'Gateway';
  static String get startGateway => _isChinese ? '启动网关' : 'Start Gateway';
  static String get stopGateway => _isChinese ? '停止网关' : 'Stop Gateway';
  static String get viewLogs => _isChinese ? '查看日志' : 'View Logs';
  static String get urlCopied =>
      _isChinese ? '链接已复制' : 'URL copied to clipboard';
  static String get copyUrl => _isChinese ? '复制链接' : 'Copy URL';
  static String get openDashboard => _isChinese ? '打开控制台' : 'Open dashboard';
  static String get gatewayRunning => _isChinese ? '运行中' : 'Running';
  static String get gatewayStarting => _isChinese ? '启动中' : 'Starting';
  static String get gatewayError => _isChinese ? '错误' : 'Error';
  static String get gatewayStopped => _isChinese ? '已停止' : 'Stopped';

  static String get enableNode => _isChinese ? '启用节点' : 'Enable Node';
  static String get disableNode => _isChinese ? '禁用节点' : 'Disable Node';
  static String get reconnect => _isChinese ? '重新连接' : 'Reconnect';
  static String get nodePaired => _isChinese ? '已配对' : 'Paired';
  static String get nodeConnecting => _isChinese ? '连接中' : 'Connecting';
  static String get nodeDisconnected => _isChinese ? '已断开' : 'Disconnected';
  static String get nodeDisabled => _isChinese ? '已禁用' : 'Disabled';
  static String get nodeConfigure => _isChinese ? '配置' : 'Configure';

  static String get settings => _isChinese ? '设置' : 'Settings';
  static String get general => _isChinese ? '通用' : 'GENERAL';
  static String get autoStartGateway =>
      _isChinese ? '自动启动网关' : 'Auto-start gateway';
  static String get autoStartSubtitle =>
      _isChinese ? '应用打开时自动启动网关' : 'Start the gateway when the app opens';
  static String get batteryOptimization =>
      _isChinese ? '电池优化' : 'Battery Optimization';
  static String get batteryOptimized =>
      _isChinese ? '已优化（可能终止后台会话）' : 'Optimized (may kill background sessions)';
  static String get batteryUnrestricted =>
      _isChinese ? '无限制（推荐）' : 'Unrestricted (recommended)';
  static String get setupStorage => _isChinese ? '存储权限' : 'Setup Storage';
  static String get storageGranted => _isChinese
      ? '已授权 — proot 可访问 /sdcard，不需要时请撤销'
      : 'Granted — proot can access /sdcard. Revoke if not needed.';
  static String get storageNotGranted =>
      _isChinese ? '允许访问共享存储' : 'Allow access to shared storage';
  static String get nodeSection => _isChinese ? '节点' : 'NODE';
  static String get enableNodeTitle => _isChinese ? '启用节点' : 'Enable Node';
  static String get enableNodeSubtitle =>
      _isChinese ? '为网关提供设备能力' : 'Provide device capabilities to the gateway';
  static String get nodeConfiguration =>
      _isChinese ? '节点配置' : 'Node Configuration';
  static String get nodeConfigSubtitle =>
      _isChinese ? '连接、配对和能力设置' : 'Connection, pairing, and capabilities';
  static String get systemInfo => _isChinese ? '系统信息' : 'SYSTEM INFO';
  static String get architecture => _isChinese ? '架构' : 'Architecture';
  static String get prootPath => _isChinese ? 'PRoot 路径' : 'PRoot path';
  static String get rootfs => _isChinese ? '根文件系统' : 'Rootfs';
  static String get installed => _isChinese ? '已安装' : 'Installed';
  static String get notInstalled => _isChinese ? '未安装' : 'Not installed';
  static String get maintenance => _isChinese ? '维护' : 'MAINTENANCE';
  static String get exportSnapshot => _isChinese ? '导出快照' : 'Export Snapshot';
  static String get exportSnapshotSubtitle =>
      _isChinese ? '备份配置到下载目录' : 'Backup config to Downloads';
  static String get importSnapshot => _isChinese ? '导入快照' : 'Import Snapshot';
  static String get importSnapshotSubtitle =>
      _isChinese ? '从备份恢复配置' : 'Restore config from backup';
  static String get rerunSetup => _isChinese ? '重新安装' : 'Re-run setup';
  static String get rerunSetupSubtitle =>
      _isChinese ? '重新安装或修复环境' : 'Reinstall or repair the environment';
  static String get about => _isChinese ? '关于' : 'ABOUT';
  static String get checkForUpdates =>
      _isChinese ? '检查更新' : 'Check for Updates';
  static String get checkUpdatesSubtitle =>
      _isChinese ? '在 GitHub 检查新版本' : 'Check GitHub for a newer release';
  static String get developer => _isChinese ? '开发者' : 'Developer';
  static String get github => 'GitHub';
  static String get contact => _isChinese ? '联系方式' : 'Contact';
  static String get license => _isChinese ? '许可证' : 'License';
  static String get updateAvailable =>
      _isChinese ? '发现新版本' : 'Update Available';
  static String get currentVersion => _isChinese ? '当前版本' : 'Current';
  static String get latestVersion => _isChinese ? '最新版本' : 'Latest';
  static String get alreadyLatest =>
      _isChinese ? '已是最新版本' : "You're on the latest version";
  static String get checkUpdateFailed =>
      _isChinese ? '无法检查更新' : 'Could not check for updates';
  static String get snapshotSaved =>
      _isChinese ? '快照已保存至' : 'Snapshot saved to';
  static String get exportFailed => _isChinese ? '导出失败' : 'Export failed';
  static String get noSnapshotFound =>
      _isChinese ? '未找到快照文件' : 'No snapshot found at';
  static String get snapshotRestored => _isChinese
      ? '快照已恢复，重启网关以应用更改'
      : 'Snapshot restored successfully. Restart the gateway to apply.';
  static String get importFailed => _isChinese ? '导入失败' : 'Import failed';

  static String get setupOpenClaw =>
      _isChinese ? '安装 OpenClaw' : 'Setup OpenClaw';
  static String get setupRunning => _isChinese
      ? '正在配置环境，可能需要几分钟。'
      : 'Setting up the environment. This may take several minutes.';
  static String get setupDescription => _isChinese
      ? '将下载 Ubuntu、Node.js 和 OpenClaw 到独立环境中。'
      : 'This will download Ubuntu, Node.js, and OpenClaw into a self-contained environment.';
  static String get downloadRootfs =>
      _isChinese ? '下载 Ubuntu 根文件系统' : 'Download Ubuntu rootfs';
  static String get extractRootfs => _isChinese ? '解压根文件系统' : 'Extract rootfs';
  static String get installNode =>
      _isChinese ? '安装 Node.js' : 'Install Node.js';
  static String get installOpenClaw =>
      _isChinese ? '安装 OpenClaw' : 'Install OpenClaw';
  static String get configureBionicBypass =>
      _isChinese ? '配置 Bionic Bypass' : 'Configure Bionic Bypass';
  static String get setupComplete => _isChinese ? '安装完成！' : 'Setup complete!';
  static String get configureApiKeys =>
      _isChinese ? '配置 API 密钥' : 'Configure API Keys';
  static String get beginSetup => _isChinese ? '开始安装' : 'Begin Setup';
  static String get retrySetup => _isChinese ? '重试安装' : 'Retry Setup';
  static String get storageRequired => _isChinese
      ? '需要约 500MB 存储空间和网络连接'
      : 'Requires ~500MB of storage and an internet connection';
  static String get optionalPackages =>
      _isChinese ? '可选扩展包' : 'OPTIONAL PACKAGES';

  static String get gatewayLogs => _isChinese ? '网关日志' : 'Gateway Logs';
  static String get filterLogs => _isChinese ? '过滤日志...' : 'Filter logs...';
  static String get noLogsYet =>
      _isChinese ? '暂无日志，请启动网关。' : 'No logs yet. Start the gateway.';
  static String get noMatchingLogs =>
      _isChinese ? '没有匹配的日志。' : 'No matching logs.';
  static String get copyAllLogs => _isChinese ? '复制全部日志' : 'Copy all logs';
  static String get autoScrollOn => _isChinese ? '自动滚动已开启' : 'Auto-scroll on';
  static String get autoScrollOff => _isChinese ? '自动滚动已关闭' : 'Auto-scroll off';

  static String get activeModel => _isChinese ? '当前模型' : 'Active Model';
  static String get selectProvider => _isChinese
      ? '选择提供商配置 API 密钥和模型。'
      : 'Select a provider to configure its API key and model.';
  static String get active => _isChinese ? '使用中' : 'Active';
  static String get configured => _isChinese ? '已配置' : 'Configured';
  static String get apiKey => _isChinese ? 'API 密钥' : 'API Key';
  static String get model => _isChinese ? '模型' : 'Model';
  static String get customModel => _isChinese ? '自定义...' : 'Custom...';
  static String get customModelHint => _isChinese
      ? '例如：meta/llama-3.3-70b-instruct'
      : 'e.g. meta/llama-3.3-70b-instruct';
  static String get customModelLabel =>
      _isChinese ? '自定义模型名称' : 'Custom model name';
  static String get saveAndActivate => _isChinese ? '保存并激活' : 'Save & Activate';
  static String get removeConfiguration =>
      _isChinese ? '移除配置' : 'Remove Configuration';
  static String get apiKeyEmpty =>
      _isChinese ? 'API 密钥不能为空' : 'API key cannot be empty';
  static String get modelEmpty =>
      _isChinese ? '模型名称不能为空' : 'Model name cannot be empty';
  static String get configuredAndActivated =>
      _isChinese ? '已配置并激活' : 'configured and activated';
  static String get saveFailed => _isChinese ? '保存失败' : 'Failed to save';
  static String get removeFailed => _isChinese ? '移除失败' : 'Failed to remove';
  static String get removeProvider => _isChinese ? '移除' : 'Remove';
  static String get removeProviderContent => _isChinese
      ? '这将删除 API 密钥并停用该模型。'
      : 'This will delete the API key and deactivate the model.';

  static String get startingTerminal =>
      _isChinese ? '正在启动终端...' : 'Starting terminal...';
  static String get failedToStartTerminal =>
      _isChinese ? '启动终端失败' : 'Failed to start terminal';

  static String get openClawOnboarding =>
      _isChinese ? 'OpenClaw 初始配置' : 'OpenClaw Onboarding';
  static String get startingOnboarding =>
      _isChinese ? '正在启动配置向导...' : 'Starting onboarding...';
  static String get goToDashboard => _isChinese ? '前往控制台' : 'Go to Dashboard';

  static String get cliProxyManagement =>
      _isChinese ? 'CLIProxy 管理中心' : 'CLIProxy Management';
  static String get cliProxyNotRunning =>
      _isChinese ? 'CLIProxy 服务未运行' : 'CLIProxy service is not running';
  static String get openInBrowser => _isChinese ? '在浏览器中打开' : 'Open in browser';

  static String translateError(String error) {
    if (!_isChinese) return error;
    if (error.contains('Download failed') || error.contains('download')) {
      return '下载失败：请检查网络连接后重试。\n$error';
    }
    if (error.contains('PROOT_ERROR') || error.contains('libproot')) {
      return '运行环境错误：proot 库缺失或不兼容当前设备架构。\n$error';
    }
    if (error.contains('No such file or directory')) {
      return '文件不存在：安装包可能不完整，请重试安装。\n$error';
    }
    if (error.contains('Permission denied')) {
      return '权限不足：请检查存储权限设置。\n$error';
    }
    if (error.contains('timeout') || error.contains('Timeout')) {
      return '连接超时：请检查网络后重试。\n$error';
    }
    if (error.contains('Setup failed')) {
      return '安装失败：$error';
    }
    return error;
  }

// Node Screen
  static String get gatewayConnection =>
      _isChinese ? '网关连接' : 'GATEWAY CONNECTION';
  static String get localGateway => _isChinese ? '本地网关' : 'Local Gateway';
  static String get localGatewaySubtitle =>
      _isChinese ? '自动与本设备上的网关配对' : 'Auto-pair with gateway on this device';
  static String get remoteGateway => _isChinese ? '远程网关' : 'Remote Gateway';
  static String get remoteGatewaySubtitle =>
      _isChinese ? '连接到另一台设备上的网关' : 'Connect to a gateway on another device';
  static String get gatewayHost => _isChinese ? '网关地址' : 'Gateway Host';
  static String get gatewayPort => _isChinese ? '网关端口' : 'Gateway Port';
  static String get gatewayToken => _isChinese ? '网关令牌' : 'Gateway Token';
  static String get gatewayTokenHint => _isChinese
      ? '从网关控制台 URL 中粘贴令牌'
      : 'Paste token from gateway dashboard URL';
  static String get gatewayTokenHelper => _isChinese
      ? '在控制台 URL 的 #token= 后面找到'
      : 'Found in dashboard URL after #token=';
  static String get connect => _isChinese ? '连接' : 'Connect';
  static String get pairing => _isChinese ? '配对' : 'PAIRING';
  static String get pairingPrompt =>
      _isChinese ? '在网关上批准此配对码：' : 'Approve this code on the gateway:';
  static String get capabilities => _isChinese ? '设备能力' : 'CAPABILITIES';
  static String get capCamera => _isChinese ? '摄像头' : 'Camera';
  static String get capCameraDesc =>
      _isChinese ? '拍摄照片和视频' : 'Capture photos and video clips';
  static String get capCanvas => _isChinese ? '画布' : 'Canvas';
  static String get capCanvasDesc =>
      _isChinese ? '移动端不可用' : 'Not available on mobile';
  static String get capLocation => _isChinese ? '位置' : 'Location';
  static String get capLocationDesc =>
      _isChinese ? '获取设备 GPS 坐标' : 'Get device GPS coordinates';
  static String get capScreen => _isChinese ? '屏幕录制' : 'Screen Recording';
  static String get capScreenDesc => _isChinese
      ? '录制设备屏幕（每次需要授权）'
      : 'Record device screen (requires consent each time)';
  static String get capFlash => _isChinese ? '手电筒' : 'Flashlight';
  static String get capFlashDesc =>
      _isChinese ? '开关设备手电筒' : 'Toggle device torch on/off';
  static String get capVibration => _isChinese ? '振动' : 'Vibration';
  static String get capVibrationDesc => _isChinese
      ? '触发触觉反馈和振动'
      : 'Trigger haptic feedback and vibration patterns';
  static String get capSensors => _isChinese ? '传感器' : 'Sensors';
  static String get capSensorsDesc => _isChinese
      ? '读取加速度计、陀螺仪、磁力计、气压计'
      : 'Read accelerometer, gyroscope, magnetometer, barometer';
  static String get capSerial => _isChinese ? '串口' : 'Serial';
  static String get capSerialDesc =>
      _isChinese ? '蓝牙和 USB 串口通信' : 'Bluetooth and USB serial communication';
  static String get deviceInfo => _isChinese ? '设备信息' : 'DEVICE INFO';
  static String get deviceId => _isChinese ? '设备 ID' : 'Device ID';
  static String get nodeLogs => _isChinese ? '节点日志' : 'NODE LOGS';
  static String get noLogsYetNode => _isChinese ? '暂无日志' : 'No logs yet';

  // Provider Detail
  static String get baseUrl => 'Base URL';
  static String get baseUrlHelper => _isChinese
      ? 'CLIProxy 默认: http://127.0.0.1:18790/v1'
      : 'CLIProxy default: http://127.0.0.1:18790/v1';

  // AI Provider descriptions
  static String get providerAnthropicDesc => _isChinese
      ? 'Claude 系列模型，擅长推理和编程'
      : 'Claude models for advanced reasoning and coding';
  static String get providerCustomDesc => _isChinese
      ? '任意 OpenAI 兼容 API（如 CLIProxy 18790 端口）'
      : 'Any OpenAI-compatible API (e.g. CLIProxy on port 18790)';
  // CLIProxy Screen
  static String get cliProxyRunning => _isChinese ? '运行中' : 'Running';
  static String get cliProxyStopped => _isChinese ? '已停止' : 'Stopped';
  static String get cliProxyRefresh => _isChinese ? '刷新' : 'Refresh';
  static String get cliProxyStop =>
      _isChinese ? '停止 CLIProxy' : 'Stop CLIProxy';
  static String get cliProxyStart =>
      _isChinese ? '启动 CLIProxy' : 'Start CLIProxy';
  static String get cliProxyStarting => _isChinese ? '正在启动...' : 'Starting...';
  static String get cliProxyInstall =>
      _isChinese ? '安装 CLIProxy' : 'Install CLIProxy';
  static String get cliProxyInstallTitle =>
      _isChinese ? '安装 CLIProxy' : 'Install CLIProxy';
  static String get cliProxyInstallDone =>
      _isChinese ? '安装完成，返回' : 'Done, go back';
  static String get cliProxyInstallStarting =>
      _isChinese ? '正在启动安装...' : 'Starting install...';
  static String get cliProxyGuide => _isChinese
      ? '点击下方按钮启动服务，或先安装 CLIProxy。'
      : 'Tap the button below to start the service, or install CLIProxy first.';
  // CLIProxy Screen
  static String get cliProxyInstallBtn =>
      _isChinese ? '安装 CLIProxy' : 'Install CLIProxy';
  // 9Router
  static String get nineRouterTerminal => _isChinese ? '9Router 终端' : '9Router Terminal';
  static String get nineRouterTerminalSubtitle => _isChinese ? '启动免费 AI 账号代理服务' : 'Start free AI account proxy';
  static String get nineRouterConsole => _isChinese ? '9Router 控制台' : '9Router Console';
  static String get nineRouterConsoleSubtitle => _isChinese ? '打开 9Router Web 管理界面' : 'Open 9Router web dashboard';
}