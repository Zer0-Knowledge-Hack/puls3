import 'package:flutter/material.dart';

import '../../domain/stellar_format.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/price_tag.dart';

/// Compact agent teaser used in the Landing hero (brand guide page 14).
class AgentMiniCard extends StatelessWidget {
  const AgentMiniCard({
    super.key,
    required this.name,
    required this.stellarAddress,
    required this.priceUsdcStroops,
    this.onTap,
  });

  final String name;
  final String stellarAddress;
  final int priceUsdcStroops;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Puls3Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: Puls3Radius.mdAll,
        side: BorderSide(color: Puls3Colors.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: Puls3Radius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(Puls3Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.smart_toy_outlined,
                    size: 20,
                    color: Puls3Colors.text,
                  ),
                  const SizedBox(width: Puls3Spacing.xs),
                  Expanded(
                    child: Text(
                      name,
                      style: Puls3Text.title.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Puls3Spacing.xs),
              Text(
                shortenAddress(stellarAddress),
                style: Puls3Text.data.copyWith(
                  fontSize: 12,
                  color: Puls3Colors.muted,
                ),
              ),
              const SizedBox(height: Puls3Spacing.xxs),
              PriceTag(stroops: priceUsdcStroops),
            ],
          ),
        ),
      ),
    );
  }
}
