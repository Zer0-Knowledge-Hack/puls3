/// Copy and facts for the landing page, kept apart from the widgets so they
/// can be reviewed in one place. Every claim here is backed by the repository
/// (docs/vision.md, the contracts, the merged PRs) or by testnet evidence.
library;

/// A pain point puls3 solves (docs/vision.md §1).
class LandingProblem {
  const LandingProblem(this.title, this.body, this.answer);

  final String title;
  final String body;

  /// How puls3 answers it.
  final String answer;
}

const landingProblems = [
  LandingProblem(
    'Building an agent that earns is slow',
    'Writing an agent takes an afternoon. Giving it an identity, a wallet, '
        'a price and a way to get paid takes custom infrastructure.',
    'The Agent Studio turns a name, a prompt, a model and a price into a '
        'checked agent definition; deploying it with its own wallet and '
        'on-chain id is coming.',
  ),
  LandingProblem(
    'Finding an agent you can trust is hard',
    'Agents are scattered across threads and repositories, with no common '
        'place to compare skills, prices or track records.',
    'One Marketplace read from an on-chain registry: search by skill, '
        'compare prices and check who the agent is.',
  ),
  LandingProblem(
    'Paying per task does not fit cards',
    'Cards and subscriptions were not built for payments of a few cents '
        'between people and machines, and they settle in days.',
    'Pay per task in USDC on Stellar, held in escrow until the result is '
        'approved, settled in seconds with sub-cent fees.',
  ),
];

/// What one audience gets.
class LandingAudience {
  const LandingAudience(this.title, this.lead, this.points);

  final String title;
  final String lead;
  final List<String> points;
}

const landingAudiences = [
  LandingAudience(
    'For builders',
    'Publish an agent once and get paid every time it works.',
    [
      'Define the agent in a form: name, skills, model, system prompt, '
          'input and output limits, price.',
      'Validation as you type, with the same rules the server applies.',
      'A Marketplace preview of your card before you publish.',
      'Coming with Studio deploy: your agent gets an id in the Identity '
          'Registry and its own Stellar wallet.',
      'Bring your own model account: free Workers AI models or your own '
          'Anthropic key.',
    ],
  ),
  LandingAudience(
    'For hirers',
    'Find an agent for a task and pay only for that task.',
    [
      'Search the catalog by skill, price and rating.',
      'See the price, the model and the on-chain identity before hiring.',
      'Your wallet signs; puls3 never holds your keys.',
      'Your USDC is checked before anything is signed, and held by the '
          'escrow contract, not sent to the agent.',
      'Every payment opens on the Stellar explorer.',
    ],
  ),
];

/// A row of the "puls3 vs a listing" comparison.
class LandingComparison {
  const LandingComparison(this.feature, this.listing, this.puls3);

  final String feature;

  /// What a directory or listing of agents usually offers.
  final String listing;
  final String puls3;
}

const landingComparison = [
  LandingComparison(
    'Find agents',
    'Links in posts and repositories',
    'One catalog read from an on-chain registry',
  ),
  LandingComparison(
    'Know who the agent is',
    'A name and a description',
    'An id and an owner in a Soroban registry (the catalog\'s agents '
        'today; yours once Studio deploy ships)',
  ),
  LandingComparison(
    'Hire',
    'Contact the author, agree off-platform',
    'Describe the task and confirm in the app',
  ),
  LandingComparison(
    'Pay',
    'Card, invoice or a direct transfer',
    'USDC held in escrow, released on approval',
  ),
  LandingComparison(
    'If the result is not delivered',
    'Ask for your money back',
    'Rejecting or expiring the job refunds the escrow',
  ),
  LandingComparison(
    'Create an agent',
    'Build auth, billing and a wallet first',
    'A form in the Agent Studio',
  ),
];

/// A team member, as they appear on GitHub.
class TeamMember {
  const TeamMember(this.handle, this.focus);

  final String handle;

  /// What they build in puls3, from the work they own in the repository.
  final String focus;

  String get profileUrl => 'https://github.com/$handle';
}

/// The Zer0-Knowledge team: the repository's contributors.
const landingTeam = [
  TeamMember('TOMOKI977', 'Product and server: Studio endpoints, deployment'),
  TeamMember('XxHugheadxX', 'Agent runtime and hire flow'),
  TeamMember('moises-cisneros', 'Server: escrow relay and payments'),
  TeamMember('Pericena', 'Flutter app: wallet, Marketplace, Studio'),
  TeamMember('fercodes', 'Soroban contracts and integrations'),
];

/// A testimonial. Only real, attributable quotes go here, with the
/// person's permission. The landing shows an invitation while it is empty.
class Testimonial {
  const Testimonial({
    required this.quote,
    required this.name,
    required this.role,
  });

  final String quote;
  final String name;
  final String role;
}

/// Empty on purpose: no invented reviews.
const landingTestimonials = <Testimonial>[];

/// A question and its answer.
class LandingFaq {
  const LandingFaq(this.question, this.answer);

  final String question;
  final String answer;
}

const landingFaqs = [
  LandingFaq(
    'What is puls3?',
    'An agent hub on Stellar. Builders define AI agents in the Agent Studio '
        'and, once Studio deploy ships, publish them with an on-chain identity '
        'and their own wallet. Anyone can find agents in the Marketplace and '
        'pay them per task in USDC.',
  ),
  LandingFaq(
    'Is this real money?',
    'Not yet. puls3 runs on Stellar Testnet with test USDC from Circle\'s '
        'faucet. The transactions are real Stellar transactions you can open '
        'on the explorer, but the funds have no value. Mainnet comes after '
        'smart-account spending limits are in place.',
  ),
  LandingFaq(
    'What do I need to hire an agent?',
    'A Stellar wallet (Freighter) on Testnet, a USDC trustline and test '
        'USDC. The app checks your balance before asking for any signature, '
        'and tells you what is missing.',
  ),
  LandingFaq(
    'Where does my payment go?',
    'Into an escrow contract on Soroban, not to the agent. Your wallet signs '
        'two transactions: one creates the job, one funds it. The server '
        'checks each one against what it prepared before sending it.',
  ),
  LandingFaq(
    'What if the agent does not deliver?',
    'The escrow is built for it: approving the result pays the agent, '
        'rejecting it or letting the job expire refunds you. The approve '
        'and reject steps in the app are still in development.',
  ),
  LandingFaq(
    'Which models can an agent use?',
    'Free Workers AI models such as Llama 3.3 70B, or Anthropic models with '
        'the builder\'s own key. The builder picks one model per agent.',
  ),
  LandingFaq(
    'How is this different from an agent directory?',
    'A directory lists agents. puls3 also gives each agent an on-chain '
        'identity, lets you hire it in the app, and holds the payment in '
        'escrow until the work is done.',
  ),
  LandingFaq(
    'Is puls3 open source?',
    'Yes. The Flutter app, the Serverpod server and the Soroban contracts '
        'are in one public repository, with the architecture decisions and '
        'the API contract documented.',
  ),
];
