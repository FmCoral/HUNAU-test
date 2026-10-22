import 'package:flutter/material.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/theme/app_tokens.dart';

enum PaymentResultType {
  success,
  failure,
  notice,
  confirm,
}

class PaymentResultSheet extends StatelessWidget {
  final PaymentResultType type;
  final String? merchantName;
  final String? amount;
  final String? message;
  final String? time;
  final String? journalNo;

  final VoidCallback? onConfirm;
  final String? confirmText;

  const PaymentResultSheet({
    super.key,
    required this.type,
    this.merchantName,
    this.amount,
    this.message,
    this.time,
    this.journalNo,
    this.onConfirm,
    this.confirmText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color themeColor;
    final IconData statusIcon;
    final String statusTitle;

    switch (type) {
      case PaymentResultType.success:
        themeColor = colors.brand;
        statusIcon = Icons.check_circle_outline;
        statusTitle = context.l10n.paymentSuccess;
        break;
      case PaymentResultType.failure:
        themeColor = colors.danger;
        statusIcon = Icons.cancel_outlined;
        statusTitle = context.l10n.paymentFailed;
        break;
      case PaymentResultType.notice:
        themeColor = colors.warning;
        statusIcon = Icons.info_outline;
        statusTitle = context.l10n.paymentNotice;
        break;
      case PaymentResultType.confirm:
        themeColor = colors.brand;
        statusIcon = Icons.payment_outlined;
        statusTitle = context.l10n.paymentConfirmation;
        break;
    }

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl, vertical: AppSpacing.xxl),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态 (左对齐，小)
          Row(
            children: [
              Icon(statusIcon, size: 20, color: themeColor),
              const SizedBox(width: AppSpacing.sm),
              Text(
                statusTitle,
                style: AppText.bodyDense.copyWith(
                  fontWeight: FontWeight.w500,
                  color: themeColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // 金额 (左对齐，关键数字)
          if ((type == PaymentResultType.success || type == PaymentResultType.confirm) && amount != null && amount!.isNotEmpty)
            Text(
              '¥$amount',
              style: AppText.keyNumber.copyWith(color: colors.text),
            ),

          // 错误消息 (如果不是成功状态)
          if (type != PaymentResultType.success && type != PaymentResultType.confirm && message != null && message!.isNotEmpty)
            Text(
              message!,
              style: AppText.pageTitle.copyWith(color: colors.text),
            ),

          const SizedBox(height: AppSpacing.sm),

          // 商户名 (如果有) (左对齐，小，淡色)
          if ((type == PaymentResultType.success || type == PaymentResultType.confirm) && merchantName != null && merchantName!.isNotEmpty)
            Text(
              merchantName!,
              style: AppText.bodyDense.copyWith(color: colors.textMuted),
            ),

          const SizedBox(height: AppSpacing.xxxl),

          // 底部操作 (右对齐)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 取消 (确认模式下)
              if (type == PaymentResultType.confirm)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
              if (type == PaymentResultType.confirm)
                const SizedBox(width: AppSpacing.lg),

              // 继续支付 (纯文字)
              if (type == PaymentResultType.success) ...[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.continuePayment),
                ),
                const SizedBox(width: AppSpacing.xxl),
              ],

              // 完成 / 确认 (主按钮交给全局主题)
              SizedBox(
                width: 100,
                height: 48,
                child: ElevatedButton(
                  onPressed: type == PaymentResultType.confirm
                    ? onConfirm
                    : () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text(
                    type == PaymentResultType.confirm ? (confirmText ?? context.l10n.confirmPayment) : context.l10n.done,
                  ),
                ),
              ),
            ],
          ),
          // 底部安全区留白
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
        ),
      ),
    );
  }
}
