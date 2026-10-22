import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// 使用前缀导入 PointyCastle 以彻底解决命名冲突并确保所有组件可用
import 'package:pointycastle/export.dart' as pc;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/theme/app_tokens.dart';

/// WebVPN 链接转换器 - 原生 UI 版
class VpnConverterScreen extends StatefulWidget {
  const VpnConverterScreen({super.key});

  @override
  State<VpnConverterScreen> createState() => _VpnConverterScreenState();
}

class _VpnConverterScreenState extends State<VpnConverterScreen> {
  final TextEditingController _urlController = TextEditingController();
  final _logger = AppLogger.instance;
  String _convertedUrl = '';
  
  // 配置信息
  final String _keyAndIv = "wwwvpnisthebest!";
  final String _vpnDomain = "webvpn.hunau.edu.cn";

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// AES-CFB-128 加密实现
  String _encryptVpnHost(String host) {
    final keyBytes = Uint8List.fromList(utf8.encode(_keyAndIv));
    final ivBytes = Uint8List.fromList(utf8.encode(_keyAndIv));
    
    // 16 字节对齐补齐 (参考 TS 的 textRightAppend)
    String paddedHost = host;
    if (host.length % 16 != 0) {
      paddedHost += '0' * (16 - (host.length % 16));
    }
    final plainBytes = Uint8List.fromList(utf8.encode(paddedHost));

    // 使用 CFBBlockCipher (AES 引擎)
    // 根据 PointyCastle 最新实践，使用 pc.AESEngine()
    final cipher = pc.CFBBlockCipher(pc.AESEngine(), 16)
      ..init(true, pc.ParametersWithIV(pc.KeyParameter(keyBytes), ivBytes));

    final encryptedBytes = Uint8List(plainBytes.length);
    var offset = 0;
    while (offset < plainBytes.length) {
      // processBlock 返回处理的字节数
      offset += cipher.processBlock(plainBytes, offset, encryptedBytes, offset);
    }

    // 转换为 Hex
    String ivHex = _toHex(ivBytes);
    // TS 逻辑：hex(iv) + hex(encrypted).slice(0, host.length * 2)
    String encryptedHex = _toHex(encryptedBytes).substring(0, host.length * 2);

    return ivHex + encryptedHex;
  }

  String _toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 转换流程主逻辑
  void _convert() {
    String input = _urlController.text.trim();
    if (input.isEmpty) {
      if (mounted) {
        setState(() {
          _convertedUrl = '';
        });
      }
      return;
    }

    try {
      String url = input;
      String protocol = 'http';
      final knownProto = ['http', 'https', 'ssh', 'vnc', 'telnet', 'rdp'];

      // 提取协议
      for (var proto in knownProto) {
        if (url.toLowerCase().startsWith('$proto://')) {
          protocol = proto;
          url = url.substring(proto.length + 3);
          break;
        }
      }

      // 处理 IPv6
      String v6 = '';
      final v6Match = RegExp(r'^\[[0-9a-fA-F:]+\]').firstMatch(url);
      if (v6Match != null) {
        v6 = v6Match.group(0)!;
        url = url.substring(v6.length);
      }

      // 处理端口
      String port = '';
      final domainPlusPath = url;
      final firstSlash = domainPlusPath.indexOf('/');
      String hostPart = firstSlash == -1 ? domainPlusPath : domainPlusPath.substring(0, firstSlash);
      String pathPart = firstSlash == -1 ? '' : domainPlusPath.substring(firstSlash);

      if (hostPart.contains(':')) {
        final parts = hostPart.split(':');
        hostPart = parts[0];
        port = parts[1];
      }

      // 还原 host (IPv6 优先级)
      String finalHost = v6.isNotEmpty ? v6 : hostPart;
      
      // 加密 host
      String encryptedHost = _encryptVpnHost(finalHost);

      // 拼接路径
      String resultPath = '';
      if (port.isNotEmpty) {
        resultPath = '/$protocol-$port/$encryptedHost$pathPart';
      } else {
        resultPath = '/$protocol/$encryptedHost$pathPart';
      }

      if (mounted) {
        setState(() {
          _convertedUrl = 'https://$_vpnDomain$resultPath';
        });
      }
    } catch (e) {
      _logger.e('URL Conversion Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.conversionFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _openInBrowser() async {
    if (_convertedUrl.isEmpty) return;
    
    try {
      await InAppBrowser.openWithSystemBrowser(url: WebUri(_convertedUrl));
    } catch (e) {
      _logger.e('Open Browser Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.openBrowserFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.webVpnConverter),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              // 顶部提示横幅
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.statusBg(colors.info),
                  borderRadius: AppRadius.innerAll,
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: colors.textMuted, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        context.l10n.webVpnDescription,
                        style: AppText.caption.copyWith(
                          color: colors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              
              // 输入框 (样式走全局主题)
              TextField(
                controller: _urlController,
                style: AppText.bodyDense.copyWith(fontSize: 15, color: colors.text),
                decoration: InputDecoration(
                  labelText: context.l10n.originalUrl,
                  hintText: 'https://jwxt.hunau.edu.cn/...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_outlined, size: 20),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _urlController.text = data!.text!;
                        _convert();
                      }
                    },
                  ),
                ),
                onChanged: (_) => _convert(),
              ),
              
              const SizedBox(height: AppSpacing.xxxl),
              
              // 转换结果展示
              if (_convertedUrl.isNotEmpty) ...[
                Text(
                  context.l10n.conversionResult,
                  style: AppText.sectionTitle.copyWith(color: colors.text),
                ),
                const SizedBox(height: AppSpacing.md),
                
                // 代码块样式的链接显示
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: AppRadius.innerAll,
                  ),
                  child: SelectableText(
                    _convertedUrl,
                    style: AppText.caption.copyWith(
                      fontFamily: 'monospace',
                      color: colors.info,
                      height: 1.4,
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.sm),
                
                // 右对齐的动作按钮栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _convertedUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.copiedToClipboard),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: Text(context.l10n.copy),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: _openInBrowser,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(context.l10n.visit),
                    ),
                  ],
                ),
              ] else ...[
                // 未输入时的占位
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xxxl),
                      Icon(Icons.link_off_outlined, size: 48, color: colors.textMuted),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        context.l10n.pasteUrlToConvertHint,
                        style: AppText.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}
