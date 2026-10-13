// DRAFT: pending brand-owner approval.
//
// All copy for the "Using puls3 in your project" section of /brand lives in
// this file so it can be reviewed in one place before it is published.

/// One numbered expectation: a short title and its explanation.
class BrandExpectation {
  const BrandExpectation(this.title, this.body);

  final String title;
  final String body;
}

/// How third-party projects may refer to puls3, an agent marketplace on
/// Stellar.
abstract final class BrandPolicy {
  static const title = 'Using puls3 in your project';

  static const intro =
      'Projects that integrate with puls3 or list agents on it are welcome '
      'to say so. These rules keep that clear and fair for everyone.';

  /// Wording projects may use to describe their integration.
  static const approvedPhrases = [
    'Built with puls3',
    'Available on puls3',
    'Powered by puls3',
  ];

  static const canDo = [
    'Say your agent or product is "Built with puls3", "Available on puls3" '
        'or "Powered by puls3".',
    'Use the official logo files from this page, unaltered, to identify '
        'your integration.',
    'Link to puls3 from your site, docs or app listing.',
    'Mention puls3 factually in articles, talks and social posts.',
  ];

  static const avoid = [
    'Implying that puls3 endorses, sponsors or partners with your project.',
    'Calling your project "Official", or describing it as "Partnering with '
        'puls3", without a written agreement.',
    'Using the puls3 name or logo in a misleading, deceptive or defamatory '
        'way.',
    'Modifying, recoloring, animating or combining the logo with other '
        'marks.',
    'Using puls3 in your product, company or domain name.',
  ];

  static const expectations = [
    BrandExpectation(
      'Follow these guidelines',
      'Use the logo, colors and wording as described on this page.',
    ),
    BrandExpectation(
      'Ask before going further',
      'Ask first for any use beyond identifying your integration, such as '
          'co-marketing, merchandise or events.',
    ),
    BrandExpectation(
      'Get approval',
      'Contact the puls3 team for approval of any use these guidelines do '
          'not cover. We may ask you to change or stop a use at any time.',
    ),
  ];

  /// Where projects ask for approval.
  // TODO(brand-owner): set the brand contact address. While it is null the
  // page renders no email link.
  static const String? contactEmail = null;
}
